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
var _mover: Node3D
var _active_touches: Dictionary = {}
var _camera_yaw: float = 0.0
var _camera_pitch: float = 0.0


func _ready() -> void:
	_camera = get_node(camera_path) as Camera3D
	_mover = get_node(mover_path) as Node3D

	var offset: Vector3 = _camera.global_position - _get_camera_target()
	if offset.length_squared() < 0.0001:
		offset = Vector3.FORWARD

	var horizontal_distance := Vector2(offset.x, offset.z).length()
	_camera_yaw = atan2(offset.x, offset.z)
	_camera_pitch = clamp(
		atan2(offset.y, horizontal_distance),
		deg_to_rad(min_camera_pitch_degrees),
		deg_to_rad(max_camera_pitch_degrees)
	)
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
			if swipe_delta.length() >= touch_steer_threshold and _mover.has_method("apply_swipe_impulse"):
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
	var surface_radius := _get_camera_surface_radius() + maxf(camera_surface_padding, 0.0)
	var horizontal_distance := cos(_camera_pitch) * surface_radius
	var surface_offset := Vector3(
		sin(_camera_yaw) * horizontal_distance,
		sin(_camera_pitch) * surface_radius,
		cos(_camera_yaw) * horizontal_distance
	)
	var surface_direction := surface_offset.normalized()
	var reference_up := _get_reference_up_direction(surface_direction)
	var right_direction := reference_up.cross(surface_direction).normalized()
	var camera_up := surface_direction.cross(right_direction).normalized()

	_camera.global_position = target + surface_offset
	_camera.look_at(_camera.global_position + surface_direction, camera_up)


func _get_camera_target() -> Vector3:
	if _mover != null:
		return _mover.global_position

	return camera_target


func _get_reference_up_direction(forward_direction: Vector3) -> Vector3:
	var up_direction := Vector3.UP
	if absf(forward_direction.dot(up_direction)) > 0.99:
		up_direction = Vector3.FORWARD

	return up_direction


func _get_camera_surface_radius() -> float:
	if _mover != null and _mover.has_method("get_surface_radius"):
		var radius_value := _mover.call("get_surface_radius")
		if radius_value is float or radius_value is int:
			return maxf(float(radius_value), 0.0)

	return 0.0
