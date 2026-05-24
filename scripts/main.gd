extends Node3D

const INITIAL_LIVES: int = 3
const ROUND_DELAY: float = 1.2
const RESET_DELAY: float = 1.6
const CAMERA_REGION_RATIO: float = 0.55
const CAMERA_DRAG_SPEED: float = 0.01
const CAMERA_ZOOM_STEP: float = 0.6

@onready var camera: Camera3D = $Camera3D
@onready var paddle = $Paddle
@onready var ball = $Ball
@onready var ball_spawn: Marker3D = $BallSpawn
@onready var block_manager = $BlockManager
@onready var miss_zone: Area3D = $MissZone
@onready var ui = $UI
@onready var round_timer: Timer = $RoundTimer
@onready var restart_timer: Timer = $RestartTimer

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _score: int = 0
var _lives: int = INITIAL_LIVES
var _round_token: int = 0
var _game_finished: bool = false
var _restart_requested: bool = false
var _camera_target: Vector3 = Vector3(0.0, -1.0, 0.0)
var _camera_yaw: float = 0.0
var _camera_pitch: float = 0.05
var _camera_distance: float = 8.2
var _camera_touch_indices: Dictionary = {}
var _right_mouse_dragging: bool = false


func _ready() -> void:
	_rng.randomize()
	_update_camera_transform()
	miss_zone.body_entered.connect(_on_miss_zone_body_entered)
	block_manager.block_broken.connect(_on_block_broken)
	block_manager.all_blocks_cleared.connect(_on_all_blocks_cleared)
	round_timer.timeout.connect(_on_round_timer_timeout)
	restart_timer.timeout.connect(_on_restart_timer_timeout)
	_start_new_game()


func _start_new_game() -> void:
	round_timer.stop()
	restart_timer.stop()
	_round_token += 1
	_game_finished = false
	_restart_requested = false
	_score = 0
	_lives = INITIAL_LIVES
	ui.update_score(_score)
	ui.update_lives(_lives)
	ui.show_message("READY")
	block_manager.reset_blocks()
	_prepare_round(_round_token, "READY", ROUND_DELAY)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _is_camera_region(touch.position):
			_camera_touch_indices[touch.index] = true
			get_viewport().set_input_as_handled()
		elif not touch.pressed and _camera_touch_indices.erase(touch.index):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _camera_touch_indices.has(drag.index):
			_orbit_camera(-drag.relative.x * CAMERA_DRAG_SPEED, -drag.relative.y * CAMERA_DRAG_SPEED)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_right_mouse_dragging = button.pressed
			get_viewport().set_input_as_handled()
		elif button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_adjust_camera_zoom(-CAMERA_ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_adjust_camera_zoom(CAMERA_ZOOM_STEP)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _right_mouse_dragging:
		var motion := event as InputEventMouseMotion
		_orbit_camera(-motion.relative.x * CAMERA_DRAG_SPEED, -motion.relative.y * CAMERA_DRAG_SPEED)
		get_viewport().set_input_as_handled()


func _prepare_round(token: int, message: String, delay: float) -> void:
	paddle.reset_paddle()
	ball.reset_ball(ball_spawn.global_transform)
	ui.show_message(message)
	round_timer.set_meta("round_token", token)
	round_timer.start(delay)


func _on_round_timer_timeout() -> void:
	var token: int = int(round_timer.get_meta("round_token", -1))
	if token != _round_token or _game_finished:
		return
	ui.show_message("")
	ball.launch(_random_launch_direction())


func _restart_after_delay(message: String) -> void:
	ui.show_message(message)
	_restart_requested = true
	restart_timer.start(RESET_DELAY)


func _on_restart_timer_timeout() -> void:
	if not _restart_requested:
		return
	_start_new_game()


func _random_launch_direction() -> Vector3:
	return Vector3(_rng.randf_range(-0.28, 0.28), _rng.randf_range(0.48, 0.72), -1.0).normalized()


func _is_camera_region(screen_position: Vector2) -> bool:
	return screen_position.y <= get_viewport().get_visible_rect().size.y * CAMERA_REGION_RATIO


func _orbit_camera(yaw_delta: float, pitch_delta: float) -> void:
	_camera_yaw += yaw_delta
	_camera_pitch = clampf(_camera_pitch + pitch_delta, deg_to_rad(-70.0), deg_to_rad(35.0))
	_update_camera_transform()


func _adjust_camera_zoom(delta: float) -> void:
	_camera_distance = clampf(_camera_distance + delta, 3.5, 18.0)
	_update_camera_transform()


func _update_camera_transform() -> void:
	var horizontal: float = cos(_camera_pitch) * _camera_distance
	var offset := Vector3(
		sin(_camera_yaw) * horizontal,
		sin(_camera_pitch) * _camera_distance,
		cos(_camera_yaw) * horizontal
	)
	camera.global_position = _camera_target + offset
	camera.look_at(_camera_target, Vector3.UP)


func _on_miss_zone_body_entered(body: Node) -> void:
	if body != ball or _game_finished:
		return

	_round_token += 1
	ball.stop_ball()
	_lives -= 1
	ui.update_lives(_lives)

	if _lives <= 0:
		_game_finished = true
		_restart_after_delay("GAME OVER")
		return

	_prepare_round(_round_token, "MISS", ROUND_DELAY)


func _on_block_broken(points: int, _remaining_blocks: int) -> void:
	_score += points
	ui.update_score(_score)


func _on_all_blocks_cleared() -> void:
	if _game_finished:
		return

	_round_token += 1
	_game_finished = true
	ball.stop_ball()
	_restart_after_delay("CLEAR!")
