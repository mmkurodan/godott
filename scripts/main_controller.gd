extends Node3D

@export_node_path("Camera3D") var camera_path: NodePath = NodePath("Camera3D")
@export_node_path("Node3D") var player_path: NodePath = NodePath("Room/Player")
@export_node_path("SubViewport") var mirror_viewport_path: NodePath = NodePath("Room/MirrorViewport")
@export_node_path("Camera3D") var mirror_camera_path: NodePath = NodePath("Room/MirrorViewport/MirrorCamera")
@export_node_path("MeshInstance3D") var mirror_surface_path: NodePath = NodePath("Room/MirrorSurface")
@export var camera_orbit_sensitivity_degrees: float = 0.15
@export var movement_tap_deadzone: float = 20.0
@export var min_camera_pitch_degrees: float = -85.0
@export var max_camera_pitch_degrees: float = 85.0
@export var camera_distance: float = 0.0
@export var min_camera_distance: float = 0.0
@export var max_camera_distance: float = 4.0
@export var pinch_zoom_sensitivity: float = 0.01

const ROOM_LAYER_MASK: int = 1 << 0
const AVATAR_LAYER_MASK: int = 1 << 1
const MIRROR_LAYER_MASK: int = 1 << 2
const FIRST_PERSON_THRESHOLD: float = 0.4
const DRAG_SWITCH_THRESHOLD: float = 20.0

# 0=tap/move  1=rotate  2=pinch
const _TOUCH_TAP: int = 0
const _TOUCH_ROTATE: int = 1
const _TOUCH_PINCH: int = 2

var _camera: Camera3D
var _player: PlayerController
var _mirror_viewport: SubViewport
var _mirror_camera: Camera3D
var _mirror_surface: MeshInstance3D
var _active_touches: Dictionary = {}
var _camera_yaw: float = PI
var _camera_pitch: float = 0.0
var _mouse_button_pressed: bool = false
var _touch_mode: int = _TOUCH_TAP
var _touch_start_pos: Vector2 = Vector2.ZERO
var _prev_pinch_dist: float = 0.0


func _ready() -> void:
	_camera = get_node(camera_path) as Camera3D
	_player = get_node(player_path) as PlayerController
	_mirror_viewport = get_node_or_null(mirror_viewport_path) as SubViewport
	_mirror_camera = get_node_or_null(mirror_camera_path) as Camera3D
	_mirror_surface = get_node_or_null(mirror_surface_path) as MeshInstance3D
	if _player != null:
		_player.set_body_yaw(_camera_yaw)
	_configure_cameras()
	_configure_mirror()
	_update_camera_transform()
	_update_mirror_camera()


func _process(_delta: float) -> void:
	if _player != null:
		_player.set_body_yaw(_camera_yaw)

	# タップ/ホールドで進行方向指定（画面中央からのベクトルで移動）
	if _active_touches.size() == 1 and _touch_mode == _TOUCH_TAP and _player != null:
		var screen_center := get_viewport().get_visible_rect().size / 2.0
		var touch_pos: Vector2 = _active_touches.values()[0]
		var dir := touch_pos - screen_center
		if dir.length() > movement_tap_deadzone:
			_player.set_movement_input(Vector2(dir.x, -dir.y).normalized())
		else:
			_player.stop_movement()

	# キーボード移動（PC用）
	var keyboard_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		keyboard_dir.y += 1
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		keyboard_dir.y -= 1
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		keyboard_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		keyboard_dir.x += 1
	if keyboard_dir.length_squared() > 0.0 and _player != null:
		_player.set_movement_input(keyboard_dir)

	_update_camera_transform()
	_update_mirror_camera()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	# 右ボタン限定: タッチ操作は右ボタンを生成しないため競合しない
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_button_pressed = event.pressed


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _mouse_button_pressed:
		_orbit_camera(event.relative)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_active_touches[event.index] = event.position
		if _active_touches.size() == 1:
			_touch_mode = _TOUCH_TAP
			_touch_start_pos = event.position
		elif _active_touches.size() == 2:
			_touch_mode = _TOUCH_PINCH
			_prev_pinch_dist = _get_pinch_distance()
			if _player != null:
				_player.stop_movement()
	else:
		_active_touches.erase(event.index)
		if _active_touches.is_empty():
			_touch_mode = _TOUCH_TAP
			if _player != null:
				_player.stop_movement()
		elif _active_touches.size() == 1:
			# ピンチ解除: 残った1本指からタップ/回転モードに戻す
			_touch_mode = _TOUCH_TAP
			_touch_start_pos = _active_touches.values()[0]


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not _active_touches.has(event.index):
		_active_touches[event.index] = event.position
		return

	var old_pos: Vector2 = _active_touches[event.index]
	_active_touches[event.index] = event.position

	if _active_touches.size() == 2:
		# ピンチズーム
		var new_dist := _get_pinch_distance()
		var delta_dist := new_dist - _prev_pinch_dist
		_prev_pinch_dist = new_dist
		camera_distance = clampf(
			camera_distance - delta_dist * pinch_zoom_sensitivity,
			min_camera_distance,
			max_camera_distance
		)
		_update_camera_cull_mask()
		return

	if _active_touches.size() != 1:
		return

	# タップからスワイプへの移行判定
	if _touch_mode == _TOUCH_TAP:
		var total_drag := (_active_touches[event.index] - _touch_start_pos).length()
		if total_drag >= DRAG_SWITCH_THRESHOLD:
			_touch_mode = _TOUCH_ROTATE
			if _player != null:
				_player.stop_movement()

	if _touch_mode == _TOUCH_ROTATE:
		_orbit_camera(event.position - old_pos)
	# _TOUCH_TAP の場合は _process で毎フレーム方向を更新


func _get_pinch_distance() -> float:
	if _active_touches.size() < 2:
		return 0.0
	var keys := _active_touches.keys()
	return (_active_touches[keys[0]] as Vector2).distance_to(_active_touches[keys[1]] as Vector2)


func _orbit_camera(screen_delta: Vector2) -> void:
	var sensitivity := deg_to_rad(camera_orbit_sensitivity_degrees)
	_camera_yaw -= screen_delta.x * sensitivity
	_camera_pitch = clampf(
		_camera_pitch - screen_delta.y * sensitivity,
		deg_to_rad(min_camera_pitch_degrees),
		deg_to_rad(max_camera_pitch_degrees)
	)
	_update_camera_transform()


func _compute_view_direction() -> Vector3:
	var yaw_basis := Basis(Vector3.UP, _camera_yaw)
	var right_direction := (yaw_basis * Vector3.RIGHT).normalized()
	var yawed_forward := (yaw_basis * Vector3.FORWARD).normalized()
	return yawed_forward.rotated(right_direction, _camera_pitch).normalized()


func _update_camera_transform() -> void:
	if _camera == null:
		return

	var view_dir := _compute_view_direction()
	var look_target := _player.get_eye_position() if _player != null else global_position
	var yaw_basis := Basis(Vector3.UP, _camera_yaw)
	var right_dir := (yaw_basis * Vector3.RIGHT).normalized()
	var cam_up := right_dir.cross(view_dir).normalized()

	if camera_distance < 0.05:
		# 一人称: カメラを目線位置に配置
		_camera.global_position = look_target
		_camera.look_at(look_target + view_dir, cam_up)
	else:
		# 三人称: カメラを後方に配置
		_camera.global_position = look_target - view_dir * camera_distance
		_camera.look_at(look_target, Vector3.UP)


func _update_camera_cull_mask() -> void:
	if _camera == null:
		return
	if camera_distance < FIRST_PERSON_THRESHOLD:
		# 一人称: アバターを非表示（頭メッシュがカメラと交差するのを防ぐ）
		_camera.cull_mask = ROOM_LAYER_MASK | MIRROR_LAYER_MASK
	else:
		# 三人称: アバターも表示
		_camera.cull_mask = ROOM_LAYER_MASK | AVATAR_LAYER_MASK | MIRROR_LAYER_MASK


func _configure_cameras() -> void:
	_update_camera_cull_mask()
	if _mirror_camera != null and _camera != null:
		# 鏡カメラは部屋とアバターを描画（鏡面自体は非表示で無限反射防止）
		_mirror_camera.cull_mask = ROOM_LAYER_MASK | AVATAR_LAYER_MASK
		_mirror_camera.near = _camera.near
		_mirror_camera.far = _camera.far
		_mirror_camera.fov = _camera.fov


func _configure_mirror() -> void:
	if _mirror_viewport == null or _mirror_surface == null or _mirror_camera == null:
		return

	_mirror_viewport.world_3d = get_viewport().world_3d
	_mirror_viewport.size = Vector2i(1024, 1024)
	_mirror_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_mirror_camera.current = true

	var mirror_material := StandardMaterial3D.new()
	mirror_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mirror_material.albedo_texture = _mirror_viewport.get_texture()
	mirror_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mirror_material.uv1_scale = Vector3(-1.0, 1.0, 1.0)
	mirror_material.uv1_offset = Vector3(1.0, 0.0, 0.0)
	_mirror_surface.material_override = mirror_material


func _update_mirror_camera() -> void:
	if _mirror_camera == null or _mirror_surface == null or _player == null:
		return

	# アバターの目線位置・向きで反射計算（三人称カメラ位置でなく等身大の鏡に見せる）
	var viewer_pos := _player.get_eye_position()
	var avatar_forward := (Basis(Vector3.UP, _camera_yaw) * Vector3.FORWARD).normalized()

	var mirror_origin := _mirror_surface.global_position
	var mirror_normal := _mirror_surface.global_basis.z.normalized()
	var reflected_pos := _reflect_point(viewer_pos, mirror_origin, mirror_normal)
	var reflected_forward := _reflect_direction(avatar_forward, mirror_normal).normalized()

	_mirror_camera.global_position = reflected_pos
	_mirror_camera.look_at(reflected_pos + reflected_forward, Vector3.UP)


func _reflect_point(point: Vector3, plane_origin: Vector3, plane_normal: Vector3) -> Vector3:
	var signed_distance := plane_normal.dot(point - plane_origin)
	return point - plane_normal * signed_distance * 2.0


func _reflect_direction(direction: Vector3, plane_normal: Vector3) -> Vector3:
	return direction - plane_normal * direction.dot(plane_normal) * 2.0
