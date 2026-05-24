extends MeshInstance3D

# 部屋の半分の長さです。
# 10m の立方体なので、中心から各壁までは 5m です。
@export var room_half_size: float = 5.0

# 球の見た目の半径です。
# 壁からはみ出さないように反射判定でも使います。
@export var object_radius: float = 0.5

# 指定どおり 3.0 m/s で移動させます。
@export var speed: float = 3.0
@export var swipe_steer_strength: float = 4.0

# 毎回違う向きに飛び出すように乱数生成器を持たせます。
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# 実際に毎フレーム使う速度ベクトルです。
var _velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	# 起動のたびに違う方向へ動くようにします。
	_rng.randomize()
	_velocity = _random_direction() * speed


func _physics_process(delta: float) -> void:
	# 重力は使わず、速度ベクトルだけで位置を更新します。
	var next_position: Vector3 = position + _velocity * delta

	# 球の中心が動ける最大範囲です。
	var limit: float = room_half_size - object_radius

	# X 軸の壁で反射します。
	if next_position.x > limit:
		next_position.x = limit
		_velocity.x *= -1.0
	elif next_position.x < -limit:
		next_position.x = -limit
		_velocity.x *= -1.0

	# Y 軸の壁で反射します。
	if next_position.y > limit:
		next_position.y = limit
		_velocity.y *= -1.0
	elif next_position.y < -limit:
		next_position.y = -limit
		_velocity.y *= -1.0

	# Z 軸の壁で反射します。
	if next_position.z > limit:
		next_position.z = limit
		_velocity.z *= -1.0
	elif next_position.z < -limit:
		next_position.z = -limit
		_velocity.z *= -1.0

	# 反射後の座標を反映します。
	position = next_position


func apply_swipe_impulse(screen_delta: Vector2, camera_basis: Basis, viewport_size: Vector2) -> void:
	var viewport_scale := maxf(1.0, minf(viewport_size.x, viewport_size.y))
	var swipe_ratio := clampf(screen_delta.length() / viewport_scale, 0.0, 1.0)

	if swipe_ratio <= 0.0:
		return

	var forward_direction := -camera_basis.z
	var world_direction := (
		camera_basis.x * screen_delta.x +
		forward_direction * -screen_delta.y
	)

	if world_direction.length_squared() < 0.0001:
		return

	var steered_velocity := _velocity + world_direction.normalized() * speed * swipe_steer_strength * swipe_ratio

	if steered_velocity.length_squared() < 0.0001:
		return

	_velocity = steered_velocity.normalized() * speed


func get_motion_direction() -> Vector3:
	if _velocity.length_squared() < 0.0001:
		return Vector3.FORWARD

	return _velocity.normalized()


func get_surface_radius() -> float:
	return object_radius


func _random_direction() -> Vector3:
	# ゼロベクトルだと正規化できないので、
	# 十分な長さのランダム方向が出るまで引き直します。
	var direction := Vector3.ZERO

	while direction.length_squared() < 0.0001:
		direction = Vector3(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0)
		)

	return direction.normalized()
