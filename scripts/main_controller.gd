extends Node3D

@export_node_path("Camera3D") var camera_path: NodePath = NodePath("Camera3D")
@export_node_path("Node3D") var player_path: NodePath = NodePath("Room/Player")
@export_node_path("SubViewport") var mirror_viewport_path: NodePath = NodePath("Room/MirrorViewport")
@export_node_path("Camera3D") var mirror_camera_path: NodePath = NodePath("Room/MirrorViewport/MirrorCamera")
@export_node_path("MeshInstance3D") var mirror_surface_path: NodePath = NodePath("Room/MirrorSurface")
@export var touch_steer_threshold: float = 4.0
@export var camera_swipe_threshold: float = 4.0
@export var camera_orbit_sensitivity_degrees: float = 0.15
@export var movement_swipe_scale: float = 8.0
@export var min_camera_pitch_degrees: float = -85.0
@export var max_camera_pitch_degrees: float = 85.0

const ROOM_LAYER_MASK: int = 1 << 0
const AVATAR_LAYER_MASK: int = 1 << 1
const MIRROR_LAYER_MASK: int = 1 << 2

var _camera: Camera3D
var _player: PlayerController
var _mirror_viewport: SubViewport
var _mirror_camera: Camera3D
var _mirror_surface: MeshInstance3D
var _active_touches: Dictionary = {}
var _camera_yaw: float = PI
var _camera_pitch: float = 0.0


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

	_update_camera_transform()
	_update_mirror_camera()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_active_touches[event.index] = event.position
	else:
		_active_touches.erase(event.index)

	if _active_touches.size() != 1 and _player != null:
		_player.stop_movement()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not _active_touches.has(event.index):
		_active_touches[event.index] = event.position
		return

	var previous_touches: Dictionary = _active_touches.duplicate()
	var previous_position: Vector2 = _active_touches[event.index]

	_active_touches[event.index] = event.position

	match _active_touches.size():
		1:
			var swipe_delta: Vector2 = event.position - previous_position
			if swipe_delta.length() >= touch_steer_threshold and _player != null:
				_player.set_movement_input(_movement_input_from_swipe(swipe_delta))
		_:
			if _player != null:
				_player.stop_movement()
			var previous_center := _average_touch_position(previous_touches)
			var current_center := _average_touch_position(_active_touches)
			var swipe_delta: Vector2 = current_center - previous_center
			if swipe_delta.length() >= camera_swipe_threshold:
				_orbit_camera(swipe_delta)


func _average_touch_position(touches: Dictionary) -> Vector2:
	if touches.is_empty():
		return Vector2.ZERO

	var sum := Vector2.ZERO

	for position in touches.values():
		sum += position as Vector2

	return sum / touches.size()


func _orbit_camera(screen_delta: Vector2) -> void:
	var sensitivity := deg_to_rad(camera_orbit_sensitivity_degrees)

	_camera_yaw -= screen_delta.x * sensitivity
	_camera_pitch = clamp(
		_camera_pitch - screen_delta.y * sensitivity,
		deg_to_rad(min_camera_pitch_degrees),
		deg_to_rad(max_camera_pitch_degrees)
	)
	_update_camera_transform()


func _movement_input_from_swipe(screen_delta: Vector2) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var viewport_scale := maxf(1.0, minf(viewport_size.x, viewport_size.y))
	return (Vector2(screen_delta.x, -screen_delta.y) * movement_swipe_scale / viewport_scale).limit_length(1.0)


func _update_camera_transform() -> void:
	if _camera == null:
		return

	var target := _get_camera_target()
	var yaw_basis := Basis(Vector3.UP, _camera_yaw)
	var right_direction := (yaw_basis * Vector3.RIGHT).normalized()
	var yawed_forward := (yaw_basis * Vector3.FORWARD).normalized()
	var view_direction := yawed_forward.rotated(right_direction, _camera_pitch).normalized()
	var camera_up := right_direction.cross(view_direction).normalized()

	_camera.global_position = target
	_camera.look_at(_camera.global_position + view_direction, camera_up)


func _get_camera_target() -> Vector3:
	if _player != null:
		return _player.get_eye_position()

	return global_position


func _configure_cameras() -> void:
	if _camera != null:
		_camera.cull_mask = ROOM_LAYER_MASK | MIRROR_LAYER_MASK

	if _mirror_camera != null and _camera != null:
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
	if _camera == null or _mirror_camera == null or _mirror_surface == null:
		return

	var mirror_origin := _mirror_surface.global_position
	var mirror_normal := _mirror_surface.global_basis.z.normalized()
	var camera_forward := -_camera.global_basis.z
	var camera_up := _camera.global_basis.y
	var reflected_position := _reflect_point(_camera.global_position, mirror_origin, mirror_normal)
	var reflected_forward := _reflect_direction(camera_forward, mirror_normal).normalized()
	var reflected_up := _reflect_direction(camera_up, mirror_normal).normalized()

	_mirror_camera.global_position = reflected_position
	_mirror_camera.look_at(reflected_position + reflected_forward, reflected_up)


func _reflect_point(point: Vector3, plane_origin: Vector3, plane_normal: Vector3) -> Vector3:
	var signed_distance := plane_normal.dot(point - plane_origin)
	return point - plane_normal * signed_distance * 2.0


func _reflect_direction(direction: Vector3, plane_normal: Vector3) -> Vector3:
	return direction - plane_normal * direction.dot(plane_normal) * 2.0
