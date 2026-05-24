extends Node3D

const INITIAL_LIVES: int = 3
const ROUND_DELAY: float = 1.2
const RESET_DELAY: float = 1.6
const CAMERA_POSITION: Vector3 = Vector3(5.6, 4.8, 14.0)
const CAMERA_TARGET: Vector3 = Vector3(0.0, -0.8, -0.6)

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


func _ready() -> void:
	_rng.randomize()
	_configure_camera()
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


func _configure_camera() -> void:
	camera.global_position = CAMERA_POSITION
	camera.look_at(CAMERA_TARGET, Vector3.UP)


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
