extends CharacterBody3D
class_name BreakoutPaddle

@export var move_speed: float = 16.0
@export var min_x: float = -4.7
@export var max_x: float = 4.7
@export var paddle_width: float = 2.6

@onready var hit_area: Area3D = $HitArea

var _target_x: float = 0.0


func _ready() -> void:
	add_to_group("paddle")
	_target_x = global_position.x
	hit_area.body_entered.connect(_on_hit_area_body_entered)


func reset_paddle() -> void:
	global_position.x = 0.0
	_target_x = 0.0
	velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_target_x = _screen_to_world_x(event.position)
	elif event is InputEventScreenDrag:
		_target_x = _screen_to_world_x(event.position)
	elif event is InputEventMouseMotion:
		_target_x = _screen_to_world_x(event.position)
	elif event is InputEventMouseButton and event.pressed:
		_target_x = _screen_to_world_x(event.position)


func _physics_process(delta: float) -> void:
	var axis: float = Input.get_axis("move_left", "move_right")
	if absf(axis) > 0.01:
		velocity.x = axis * move_speed
	else:
		var next_x := move_toward(global_position.x, _target_x, move_speed * delta)
		velocity.x = (next_x - global_position.x) / maxf(delta, 0.0001)

	velocity.y = 0.0
	velocity.z = 0.0
	move_and_slide()

	global_position.x = clampf(global_position.x, min_x, max_x)
	global_position.y = -4.2
	global_position.z = 5.4


func _screen_to_world_x(screen_position: Vector2) -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return _target_x

	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	if absf(ray_direction.y) < 0.0001:
		return _target_x

	var distance := (global_position.y - ray_origin.y) / ray_direction.y
	return clampf(ray_origin.x + ray_direction.x * distance, min_x, max_x)


func _on_hit_area_body_entered(body: Node) -> void:
	if not body.is_in_group("ball"):
		return

	if body.has_method("apply_paddle_bounce"):
		var offset := clampf((body.global_position.x - global_position.x) / (paddle_width * 0.5), -1.0, 1.0)
		body.call("apply_paddle_bounce", offset)
