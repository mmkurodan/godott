extends Node3D
class_name PlayerController

const EPSILON: float = 0.0001

@export var avatar_scene: PackedScene
@export var room_half_size: float = 5.0
@export var floor_y: float = -5.0
@export var walk_speed: float = 2.4
@export var wall_padding: float = 0.2
@export var avatar_layer_number: int = 2
@export var preferred_head_bone_name: StringName = &"headfront"
@export var fallback_head_bone_name: StringName = &"Head"

var _avatar_root: Node3D
var _skeleton: Skeleton3D
var _head_anchor: BoneAttachment3D
var _animation_player: AnimationPlayer
var _movement_input: Vector2 = Vector2.ZERO
var _movement_timeout: float = 0.0
var _avatar_radius: float = 0.35


func _ready() -> void:
	position.y = floor_y
	_instance_avatar()
	_align_avatar_to_floor()
	_configure_avatar_visuals()
	_configure_animation()
	_create_head_anchor()


func _process(delta: float) -> void:
	if _movement_timeout > 0.0:
		_movement_timeout = maxf(_movement_timeout - delta, 0.0)
	else:
		_movement_input = Vector2.ZERO

	var is_moving := _movement_input.length_squared() > EPSILON
	if is_moving:
		var local_direction := Vector3(_movement_input.x, 0.0, -_movement_input.y)
		var world_direction := (basis * local_direction).normalized()
		global_position += world_direction * walk_speed * minf(_movement_input.length(), 1.0) * delta
		_clamp_to_room()

	_update_animation_state(is_moving)


func set_movement_input(input_direction: Vector2) -> void:
	_movement_input = input_direction.limit_length(1.0)
	_movement_timeout = 0.12 if _movement_input.length_squared() > EPSILON else 0.0


func stop_movement() -> void:
	_movement_input = Vector2.ZERO
	_movement_timeout = 0.0


func set_body_yaw(yaw: float) -> void:
	rotation.y = yaw


func get_eye_position() -> Vector3:
	if _head_anchor != null:
		return _head_anchor.global_position

	return global_position + Vector3(0.0, 1.6, 0.0)


func _instance_avatar() -> void:
	if avatar_scene == null:
		push_error("PlayerController: avatar_scene is not assigned.")
		return

	_avatar_root = avatar_scene.instantiate() as Node3D
	if _avatar_root == null:
		push_error("PlayerController: avatar_scene did not instantiate a Node3D.")
		return

	add_child(_avatar_root)
	_skeleton = _find_first_node_of_type(_avatar_root, "Skeleton3D") as Skeleton3D
	_animation_player = _find_first_node_of_type(_avatar_root, "AnimationPlayer") as AnimationPlayer


func _align_avatar_to_floor() -> void:
	if _avatar_root == null:
		return

	var avatar_bounds := _compute_combined_avatar_aabb()
	if avatar_bounds.size == Vector3.ZERO:
		return

	_avatar_root.position.y -= avatar_bounds.position.y
	_avatar_radius = _compute_avatar_radius(avatar_bounds)


func _configure_avatar_visuals() -> void:
	if _avatar_root == null:
		return

	var avatar_mask := 1 << (avatar_layer_number - 1)
	for mesh_instance in _find_mesh_instances(_avatar_root):
		mesh_instance.layers = avatar_mask

		if mesh_instance.material_override != null:
			mesh_instance.material_override = _duplicate_double_sided_material(mesh_instance.material_override)

		if mesh_instance.mesh == null:
			continue

		for surface_index in mesh_instance.mesh.get_surface_count():
			var source_material := mesh_instance.get_active_material(surface_index)
			if source_material == null:
				continue

			mesh_instance.set_surface_override_material(
				surface_index,
				_duplicate_double_sided_material(source_material)
			)


func _configure_animation() -> void:
	if _animation_player == null:
		return

	var animation_list := _animation_player.get_animation_list()
	if animation_list.is_empty():
		return

	var animation_name: StringName = animation_list[0]
	var animation := _animation_player.get_animation(animation_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR

	_animation_player.play(animation_name)
	_animation_player.speed_scale = 0.0


func _update_animation_state(is_moving: bool) -> void:
	if _animation_player == null:
		return

	_animation_player.speed_scale = 1.0 if is_moving else 0.0


func _create_head_anchor() -> void:
	if _skeleton == null:
		return

	var bone_name := preferred_head_bone_name
	if _skeleton.find_bone(bone_name) == -1:
		bone_name = fallback_head_bone_name

	if _skeleton.find_bone(bone_name) == -1:
		return

	_head_anchor = BoneAttachment3D.new()
	_head_anchor.name = "HeadAnchor"
	_head_anchor.bone_name = bone_name
	_skeleton.add_child(_head_anchor)

	if bone_name == fallback_head_bone_name:
		_head_anchor.position = Vector3(0.0, 0.08, 0.08)


func _clamp_to_room() -> void:
	var travel_limit := maxf(room_half_size - _avatar_radius - wall_padding, 0.0)
	global_position.x = clampf(global_position.x, -travel_limit, travel_limit)
	global_position.z = clampf(global_position.z, -travel_limit, travel_limit)
	global_position.y = floor_y


func _compute_combined_avatar_aabb() -> AABB:
	var has_bounds := false
	var combined_aabb := AABB()

	if _avatar_root == null:
		return combined_aabb

	var inverse_transform := _avatar_root.global_transform.affine_inverse()
	for mesh_instance in _find_mesh_instances(_avatar_root):
		if mesh_instance.mesh == null:
			continue

		var local_aabb := _transform_aabb(mesh_instance.get_aabb(), inverse_transform * mesh_instance.global_transform)
		if not has_bounds:
			combined_aabb = local_aabb
			has_bounds = true
		else:
			combined_aabb = combined_aabb.merge(local_aabb)

	return combined_aabb


func _compute_avatar_radius(avatar_bounds: AABB) -> float:
	var max_radius := 0.35

	for x_value in [avatar_bounds.position.x, avatar_bounds.end.x]:
		for z_value in [avatar_bounds.position.z, avatar_bounds.end.z]:
			max_radius = maxf(max_radius, Vector2(x_value, z_value).length())

	return max_radius


func _transform_aabb(source_aabb: AABB, transform_3d: Transform3D) -> AABB:
	var corners := [
		source_aabb.position,
		source_aabb.position + Vector3(source_aabb.size.x, 0.0, 0.0),
		source_aabb.position + Vector3(0.0, source_aabb.size.y, 0.0),
		source_aabb.position + Vector3(0.0, 0.0, source_aabb.size.z),
		source_aabb.position + Vector3(source_aabb.size.x, source_aabb.size.y, 0.0),
		source_aabb.position + Vector3(source_aabb.size.x, 0.0, source_aabb.size.z),
		source_aabb.position + Vector3(0.0, source_aabb.size.y, source_aabb.size.z),
		source_aabb.position + source_aabb.size,
	]

	var transformed_aabb := AABB(transform_3d * corners[0], Vector3.ZERO)
	for corner in corners.slice(1):
		transformed_aabb = transformed_aabb.expand(transform_3d * corner)

	return transformed_aabb


func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(node, mesh_instances)
	return mesh_instances


func _collect_mesh_instances(node: Node, mesh_instances: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		mesh_instances.append(node as MeshInstance3D)

	for child in node.get_children():
		_collect_mesh_instances(child, mesh_instances)


func _find_first_node_of_type(root: Node, type_name: String) -> Node:
	if root.is_class(type_name):
		return root

	for child in root.get_children():
		var found := _find_first_node_of_type(child, type_name)
		if found != null:
			return found

	return null


func _duplicate_double_sided_material(source_material: Material) -> Material:
	var duplicated_material := source_material.duplicate() as Material
	if duplicated_material is BaseMaterial3D:
		duplicated_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	return duplicated_material
