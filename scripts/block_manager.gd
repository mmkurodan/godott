extends Node3D

signal block_broken(points: int, remaining_blocks: int)
signal all_blocks_cleared

@export var block_scene: PackedScene
@export var columns: int = 7
@export var rows: int = 4
@export var layers: int = 2
@export var spacing: Vector3 = Vector3(1.35, 0.75, 1.1)
@export var origin: Vector3 = Vector3(-4.05, 1.25, -2.3)

var _remaining_blocks: int = 0
var _palette: Array[Color] = [
	Color(0.98, 0.37, 0.47, 1.0),
	Color(0.99, 0.62, 0.27, 1.0),
	Color(0.98, 0.87, 0.25, 1.0),
	Color(0.42, 0.88, 0.49, 1.0),
	Color(0.28, 0.74, 0.98, 1.0),
	Color(0.63, 0.48, 0.97, 1.0)
]


func reset_blocks() -> void:
	for child in get_children():
		child.free()

	_remaining_blocks = 0
	if block_scene == null:
		return

	for layer in range(layers):
		for row in range(rows):
			for column in range(columns):
				var block := block_scene.instantiate() as Node3D
				if block == null:
					continue
				add_child(block)
				block.position = origin + Vector3(column * spacing.x, row * spacing.y, layer * spacing.z)
				if block.has_method("set_block_color"):
					block.call("set_block_color", _palette[(row + column + layer) % _palette.size()])
				block.connect("broken", Callable(self, "_on_block_broken"))
				_remaining_blocks += 1


func _on_block_broken(points: int) -> void:
	_remaining_blocks -= 1
	block_broken.emit(points, _remaining_blocks)
	if _remaining_blocks <= 0:
		all_blocks_cleared.emit()
