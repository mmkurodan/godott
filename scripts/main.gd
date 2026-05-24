extends Node3D

const INITIAL_LIVES: int = 3
const ROUND_DELAY: float = 0.9
const RESET_DELAY: float = 1.6

@onready var paddle = $Paddle
@onready var ball = $Ball
@onready var ball_spawn: Marker3D = $BallSpawn
@onready var block_manager = $BlockManager
@onready var miss_zone: Area3D = $MissZone
@onready var ui = $UI

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _score: int = 0
var _lives: int = INITIAL_LIVES
var _round_token: int = 0
var _game_finished: bool = false


func _ready() -> void:
	_rng.randomize()
	miss_zone.body_entered.connect(_on_miss_zone_body_entered)
	block_manager.block_broken.connect(_on_block_broken)
	block_manager.all_blocks_cleared.connect(_on_all_blocks_cleared)
	_start_new_game()


func _start_new_game() -> void:
	_round_token += 1
	_game_finished = false
	_score = 0
	_lives = INITIAL_LIVES
	ui.update_score(_score)
	ui.update_lives(_lives)
	block_manager.reset_blocks()
	_prepare_round(_round_token, "READY", ROUND_DELAY)


func _prepare_round(token: int, message: String, delay: float) -> void:
	paddle.reset_paddle()
	ball.reset_ball(ball_spawn.global_transform)
	ui.show_message(message)
	_schedule_launch_round(token, delay)


func _schedule_launch_round(token: int, delay: float) -> void:
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void:
		if token != _round_token or _game_finished:
			return
		ui.show_message("")
		ball.launch(_random_launch_direction())
	)


func _restart_after_delay(message: String) -> void:
	var token := _round_token
	ui.show_message(message)
	var timer := get_tree().create_timer(RESET_DELAY)
	timer.timeout.connect(func() -> void:
		if token != _round_token:
			return
		_start_new_game()
	)


func _random_launch_direction() -> Vector3:
	return Vector3(_rng.randf_range(-0.28, 0.28), _rng.randf_range(0.48, 0.72), -1.0).normalized()


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
