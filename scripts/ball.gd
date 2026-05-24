extends RigidBody3D

@export var speed: float = 10.5
@export var paddle_side_strength: float = 0.85
@export var paddle_lift: float = 0.52


func _ready() -> void:
	add_to_group("ball")
	gravity_scale = 0.0
	continuous_cd = RigidBody3D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 8


func reset_ball(spawn_transform: Transform3D) -> void:
	freeze = true
	sleeping = false
	global_transform = spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func launch(direction: Vector3) -> void:
	freeze = false
	sleeping = false
	linear_velocity = _sanitize_direction(direction) * speed


func stop_ball() -> void:
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func apply_paddle_bounce(offset: float) -> void:
	var direction := Vector3(offset * paddle_side_strength, paddle_lift, -1.0)
	linear_velocity = direction.normalized() * speed


func bounce_from_block(block_center: Vector3, block_size: Vector3) -> void:
	var direction := linear_velocity
	if direction.length_squared() < 0.0001:
		direction = Vector3(0.0, 0.45, -1.0)

	var local := global_position - block_center
	var half_size := block_size * 0.5
	var normalized := Vector3(
		absf(local.x) / maxf(half_size.x, 0.001),
		absf(local.y) / maxf(half_size.y, 0.001),
		absf(local.z) / maxf(half_size.z, 0.001)
	)

	if normalized.y >= normalized.x and normalized.y >= normalized.z:
		direction.y *= -1.0
	elif normalized.x >= normalized.z:
		direction.x *= -1.0
	else:
		direction.z *= -1.0

	linear_velocity = _sanitize_direction(direction) * speed


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if freeze:
		return

	var direction := _sanitize_direction(state.linear_velocity)
	state.linear_velocity = direction * speed


func _sanitize_direction(direction: Vector3) -> Vector3:
	if direction.length_squared() < 0.0001:
		direction = Vector3(0.0, 0.45, -1.0)

	if absf(direction.y) < 0.2:
		direction.y = 0.2 if direction.y >= 0.0 else -0.2

	if absf(direction.z) < 0.22:
		direction.z = 0.22 if direction.z >= 0.0 else -0.22

	return direction.normalized()
