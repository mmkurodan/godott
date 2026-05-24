extends Area3D

signal broken(points: int)

@export var points: int = 100
@export var block_size: Vector3 = Vector3(1.08, 0.52, 0.82)
@export var block_color: Color = Color(0.95, 0.31, 0.5, 1.0)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _destroyed: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var material := mesh_instance.material_override
	if material == null:
		material = StandardMaterial3D.new()
	else:
		material = material.duplicate()
	mesh_instance.material_override = material
	_apply_color()


func set_block_color(color: Color) -> void:
	block_color = color
	if is_node_ready():
		_apply_color()


func _apply_color() -> void:
	var material := mesh_instance.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = block_color
		material.emission_enabled = true
		material.emission = block_color * 0.2


func _on_body_entered(body: Node) -> void:
	if _destroyed or not body.is_in_group("ball"):
		return

	_destroyed = true
	if body.has_method("bounce_from_block"):
		body.call("bounce_from_block", global_position, block_size)
	broken.emit(points)
	queue_free()
