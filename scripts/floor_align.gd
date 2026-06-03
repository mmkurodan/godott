extends Node3D

@export var floor_y: float = -5.0

func _ready() -> void:
	call_deferred("_align_to_floor")

func _align_to_floor() -> void:
	var min_y := _find_min_y(self)
	if min_y < INF:
		global_position.y += floor_y - min_y

func _find_min_y(node: Node) -> float:
	var result := INF
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var local_aabb := mi.get_aabb()
			var gt := mi.global_transform
			for corner in _aabb_corners(local_aabb):
				result = minf(result, (gt * corner).y)
	for child in node.get_children():
		result = minf(result, _find_min_y(child))
	return result

func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	return [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0.0, 0.0),
		aabb.position + Vector3(0.0, aabb.size.y, 0.0),
		aabb.position + Vector3(0.0, 0.0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0.0),
		aabb.position + Vector3(aabb.size.x, 0.0, aabb.size.z),
		aabb.position + Vector3(0.0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size,
	]
