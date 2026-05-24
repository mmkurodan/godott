extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var lives_label: Label = $LivesLabel
@onready var message_label: Label = $MessageLabel


func update_score(value: int) -> void:
	score_label.text = "SCORE: %d" % value


func update_lives(value: int) -> void:
	lives_label.text = "LIVES: %d" % value


func show_message(message: String) -> void:
	message_label.text = message
