extends Node3D

@export_node_path("Camera3D") var camera_path: NodePath = NodePath("Camera3D")
@export_node_path("Node3D") var mover_path: NodePath = NodePath("Room/Mover")
@export var camera_target: Vector3 = Vector3.ZERO
@export var touch_steer_threshold: float = 6.0
@export var camera_swipe_threshold: float = 4.0
@export var camera_orbit_sensitivity_degrees: float = 0.15
@export var camera_surface_padding: float = 0.02
@export var min_camera_pitch_degrees: float = -85.0
@export var max_camera_pitch_degrees: float = 85.0

var _camera: Camera3D
var _mover: Mover
var _active_touches: Dictionary = {}
var _camera_yaw: float = 0.0
var _camera_pitch: float = 0.0


func _ready() -> void:
	_camera = get_node(camera_path) as Camera3D
	_mover = get_node(mover_path) as Mover
	_update_camera_transform()


func _process(_delta: float) -> void:
	_update_camera_transform()


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
			if swipe_delta.length() >= touch_steer_threshold and _mover != null:
				_mover.apply_swipe_impulse(swipe_delta, _camera.global_basis, get_viewport().get_visible_rect().size)
		2:
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
		_camera_pitch + screen_delta.y * sensitivity,
		deg_to_rad(min_camera_pitch_degrees),
		deg_to_rad(max_camera_pitch_degrees)
	)
	_update_camera_transform()


func _update_camera_transform() -> void:
	var target := _get_camera_target()
	var reference_forward := _get_reference_forward_direction()
	var reference_up := _get_reference_up_direction(reference_forward)
	var yawed_forward := reference_forward.rotated(reference_up, _camera_yaw).normalized()
	var right_direction := reference_up.cross(yawed_forward).normalized()
	var view_direction := yawed_forward.rotated(right_direction, _camera_pitch).normalized()
	var camera_up := view_direction.cross(right_direction).normalized()

	_camera.global_position = target + view_direction * _get_camera_surface_radius()
	_camera.look_at(_camera.global_position + view_direction, camera_up)


func _get_camera_target() -> Vector3:
	if _mover != null:
		return _mover.global_position

	return camera_target


func _get_reference_forward_direction() -> Vector3:
	if _mover != null:
		var direction := _mover.get_motion_direction()
		if direction.length_squared() > 0.0001:
			return direction.normalized()

	return Vector3.FORWARD


func _get_reference_up_direction(forward_direction: Vector3) -> Vector3:
	var up_direction := Vector3.UP
	if absf(forward_direction.dot(up_direction)) > 0.99:
		up_direction = Vector3.FORWARD

	return up_direction


func _get_camera_surface_radius() -> float:
	if _mover != null:
		return maxf(_mover.get_surface_radius() + maxf(camera_surface_padding, 0.0), 0.0)

	return 0.0
