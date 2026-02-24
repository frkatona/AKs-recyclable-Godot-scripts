@tool
extends Node3D
## Scatters environment prop meshes (trees, rocks, bushes) using MultiMeshInstance3D.
## Density = instances per 100 square units of scatter area.
## Attach to a Node3D in the scene. Toggle "regenerate" to rebuild.

## ──────── Per-Type Density (instances per 100 sq units) ────────
@export_group("Density")
@export var density_conicaltree: float = 0.3
@export var density_roundtree: float = 0.15
@export var density_spreadingtree: float = 0.06
@export var density_bush: float = 0.25
@export var density_rocklarge: float = 0.04
@export var density_rock_medium1: float = 0.1
@export var density_rock_medium2: float = 0.1
@export var density_rock_small: float = 0.2

## ──────── Per-Type Scale ────────
@export_group("Scale")
@export var scale_conicaltree: float = 1.2
@export var scale_roundtree: float = 1.2
@export var scale_spreadingtree: float = 1.0
@export var scale_bush: float = 0.9
@export var scale_rocklarge: float = 1.1
@export var scale_rock_medium1: float = 1.0
@export var scale_rock_medium2: float = 1.0
@export var scale_rock_small: float = 0.75

## ──────── Scatter Area ────────
@export_group("Scatter Area")
@export var scatter_center := Vector2(-24.0, 91.0)
@export var scatter_half_extents := Vector2(80.0, 100.0)
@export var scatter_seed: int = 12345
@export var ground_y: float = -5.3

## ──────── Controls ────────
@export_group("Controls")
@export var regenerate: bool = false: set = _set_regenerate

## ──────── Exclusion Zones ────────
@export_group("Exclusion Zones")
## Each Vector3 = (world_x, world_z, radius)
@export var exclusion_zones: Array[Vector3] = [
	Vector3(106.8, 82.3, 15.0), # cabin
	Vector3(-6.14, -12.9, 8.0), # shack
	Vector3(-124.0, 252.0, 30.0), # cathedral
	Vector3(63.0, 102.2, 5.0), # bonfire
]


## ──────── Internal ────────

class PropDef:
	var mesh_path: String
	var count: int
	var scale: float
	var y_offset: float
	var random_tilt: float # max XZ tilt in degrees

	func _init(p: String, c: int, s: float, yoff: float = 0.0, tilt: float = 0.0):
		mesh_path = p
		count = c
		scale = s
		y_offset = yoff
		random_tilt = tilt


func _count_from_density(density: float) -> int:
	var area := scatter_half_extents.x * 2.0 * scatter_half_extents.y * 2.0
	return maxi(0, roundi(density * area / 100.0))


func _get_prop_defs() -> Array:
	return [
		PropDef.new("res://assets/environment/conical-tree.glb", _count_from_density(density_conicaltree), scale_conicaltree, 0.0, 0.0),
		PropDef.new("res://assets/environment/round-tree.glb", _count_from_density(density_roundtree), scale_roundtree, 0.0, 0.0),
		PropDef.new("res://assets/environment/spreading-tree.glb", _count_from_density(density_spreadingtree), scale_spreadingtree, 0.0, 0.0),
		PropDef.new("res://assets/environment/bush.glb", _count_from_density(density_bush), scale_bush, 0.0, 5.0),
		PropDef.new("res://assets/environment/rock-large.glb", _count_from_density(density_rocklarge), scale_rocklarge, -0.3, 15.0),
		PropDef.new("res://assets/environment/rock-medium_1.glb", _count_from_density(density_rock_medium1), scale_rock_medium1, -0.15, 20.0),
		PropDef.new("res://assets/environment/rock-medium_2.glb", _count_from_density(density_rock_medium2), scale_rock_medium2, -0.15, 20.0),
		PropDef.new("res://assets/environment/rock-small.glb", _count_from_density(density_rock_small), scale_rock_small, -0.05, 25.0),
	]


func _set_regenerate(value: bool) -> void:
	if value:
		_build_all()
		regenerate = false


func _ready() -> void:
	_build_all()


func _build_all() -> void:
	for child in get_children():
		child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed

	for prop_def in _get_prop_defs():
		_scatter_prop(prop_def, rng)


func _scatter_prop(prop_def: PropDef, rng: RandomNumberGenerator) -> void:
	if prop_def.count <= 0:
		return

	var scene: PackedScene = load(prop_def.mesh_path)
	if scene == null:
		push_warning("mesh_scatter: could not load " + prop_def.mesh_path)
		return

	var mesh := _extract_mesh_from_scene(scene)
	if mesh == null:
		push_warning("mesh_scatter: no MeshInstance3D found in " + prop_def.mesh_path)
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = prop_def.count
	mm.mesh = mesh

	var placed := 0
	var max_attempts := prop_def.count * 10
	var attempts := 0

	while placed < prop_def.count and attempts < max_attempts:
		attempts += 1

		var x := rng.randf_range(
			scatter_center.x - scatter_half_extents.x,
			scatter_center.x + scatter_half_extents.x
		)
		var z := rng.randf_range(
			scatter_center.y - scatter_half_extents.y,
			scatter_center.y + scatter_half_extents.y
		)

		if _in_exclusion_zone(x, z):
			continue

		# Random Y rotation (full 360°)
		var rot_y := rng.randf_range(0.0, TAU)

		# ±20% random variation around the base scale
		var s := prop_def.scale * rng.randf_range(0.8, 1.2)

		var basis := Basis(Vector3.UP, rot_y)

		# Random X/Z tilt for natural look (rocks, bushes)
		if prop_def.random_tilt > 0.0:
			var tilt_rad := deg_to_rad(prop_def.random_tilt)
			var tilt_x := rng.randf_range(-tilt_rad, tilt_rad)
			var tilt_z := rng.randf_range(-tilt_rad, tilt_rad)
			basis = basis * Basis(Vector3.RIGHT, tilt_x) * Basis(Vector3.FORWARD, tilt_z)

		basis = basis.scaled(Vector3(s, s, s))

		var origin := Vector3(x, ground_y + prop_def.y_offset, z)
		var world_xform := Transform3D(basis, origin)
		var local_xform := global_transform.affine_inverse() * world_xform
		mm.set_instance_transform(placed, local_xform)
		placed += 1

	if placed < prop_def.count:
		mm.instance_count = placed

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var base_name := prop_def.mesh_path.get_file().get_basename()
	mmi.name = base_name.capitalize().replace(" ", "")
	add_child(mmi)
	if Engine.is_editor_hint():
		mmi.owner = get_tree().edited_scene_root


func _in_exclusion_zone(x: float, z: float) -> bool:
	for zone in exclusion_zones:
		var dx := x - zone.x
		var dz := z - zone.y
		if dx * dx + dz * dz < zone.z * zone.z:
			return true
	return false


func _extract_mesh_from_scene(scene: PackedScene) -> Mesh:
	var instance := scene.instantiate()
	var mesh := _find_mesh_recursive(instance)
	instance.queue_free()
	return mesh


func _find_mesh_recursive(node: Node) -> Mesh:
	if node is MeshInstance3D and node.mesh != null:
		return node.mesh
	for child in node.get_children():
		var m := _find_mesh_recursive(child)
		if m != null:
			return m
	return null
