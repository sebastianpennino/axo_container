@tool
class_name AxoContainer
extends Container

enum GridType { ORTHOGONAL, STAGGERED }
enum OrderingMode { STANDARD, SPIRAL, REVERSE, BOTTOM_UP }

## Defines the geometric structure: a straight grid or a staggered brick-like pattern.
@export var grid_type: GridType = GridType.ORTHOGONAL:
	set(v):
		grid_type = v
		queue_sort()
		queue_redraw()
## When using STAGGERED, determines if even or odd rows lose a position and get offset.
@export var stagger_even_rows: bool = true:
	set(v):
		stagger_even_rows = v
		queue_sort()
		queue_redraw()
## If true, children with visible = false still occupy a slot in the grid (they will leave a visible gap).
@export var include_hidden_nodes: bool = true:
	set(v):
		include_hidden_nodes = v
		queue_sort()
		queue_redraw()
## Determines the sequence in which children fill the available grid slots.
@export var ordering: OrderingMode = OrderingMode.STANDARD:
	set(v):
		ordering = v
		queue_sort()
		queue_redraw()

## Total number of positions along the primary axonometric axis.
@export_range(1, 20) var primary_axis_count: int = 2:
	set(v):
		primary_axis_count = v
		queue_sort()
		queue_redraw()
## Total number of positions along the secondary axonometric axis.
@export_range(1, 20) var secondary_axis_count: int = 3:
	set(v):
		secondary_axis_count = v
		queue_sort()
		queue_redraw()

@export_group("Axonometric Angles")
## Angle in degrees for the primary axis direction.
@export_range(-360.0, 360.0) var primary_axis_angle: float = -200.0:
	set(v):
		primary_axis_angle = v
		queue_sort()
		queue_redraw()
## Angle in degrees for the secondary axis direction.
@export_range(-360.0, 360.0) var secondary_axis_angle: float = 25.0:
	set(v):
		secondary_axis_angle = v
		queue_sort()
		queue_redraw()

@export_group("Spacing & Scale")
## Horizontal distance multiplier between items along the primary axis.
@export_range(0.1, 4.0) var primary_axis_spacing: float = 0.5:
	set(v):
		primary_axis_spacing = v
		queue_sort()
		queue_redraw()
## Vertical distance multiplier between items along the secondary axis.
@export_range(0.1, 4.0) var secondary_axis_spacing: float = 0.6:
	set(v):
		secondary_axis_spacing = v
		queue_sort()
		queue_redraw()
## Uniform scale applied to all children within the container.
@export_range(0.1, 4.0) var child_scale: float = 0.5:
	set(v):
		child_scale = v
		queue_sort()
		queue_redraw()

@export_group("Debug & Animation")
## Toggles the editor-only visualization of the grid lines and slot positions.
@export var show_debug_grid: bool = true:
	set(v):
		show_debug_grid = v
		queue_redraw()
## Duration in seconds for the smooth transition of children to their slots.
@export var tween_duration: float = 0.3


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_resort_children()


func _is_row_staggered(index: int) -> bool:
	if grid_type == GridType.ORTHOGONAL:
		return false
	return (index % 2 == 0) if stagger_even_rows else (index % 2 == 1)


func _get_grid_params() -> Dictionary:
	var children = get_children().filter(
		func(c):
			return c is Control and (include_hidden_nodes or c.visible)
	)
	var base_size = Vector2(64, 64)
	if not children.is_empty():
		base_size = children[0].get_combined_minimum_size()

	var unit_p = base_size.x * primary_axis_spacing
	var unit_s = base_size.y * secondary_axis_spacing
	var dir_p = Vector2.from_angle(deg_to_rad(primary_axis_angle))
	var dir_s = Vector2.from_angle(deg_to_rad(secondary_axis_angle))
	var origin = (size / 2.0) - (dir_p * (primary_axis_count - 1) * unit_p / 2.0) - (dir_s * (secondary_axis_count - 1) * unit_s / 2.0)

	return {
		"origin": origin,
		"dir_p": dir_p,
		"dir_s": dir_s,
		"unit_p": unit_p,
		"unit_s": unit_s,
		"children": children,
	}


func _resort_children() -> void:
	var p = _get_grid_params()
	if p.children.is_empty():
		return
	var slots = _get_sorted_slots()

	for i in range(p.children.size()):
		var child = p.children[i]
		child.pivot_offset = child.size / 2.0
		child.scale = Vector2.ONE * child_scale
		if i < slots.size():
			var slot_coord = slots[i]
			var stagger = 0.5 if _is_row_staggered(int(slot_coord.y)) else 0.0
			var target_center = p.origin + (p.dir_p * (slot_coord.x + stagger) * p.unit_p) + (p.dir_s * slot_coord.y * p.unit_s)
			var final_pos = target_center - (child.size / 2.0)
			var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			tween.tween_property(child, "position", final_pos, tween_duration)
	queue_redraw()


func _get_sorted_slots() -> Array[Vector2]:
	var slots: Array[Vector2] = []
	for s in range(secondary_axis_count):
		var row_count = primary_axis_count - 1 if _is_row_staggered(s) else primary_axis_count
		for p in range(row_count):
			slots.append(Vector2(p, s))

	var center_p = (primary_axis_count - 1.0) / 2.0
	var center_s = (secondary_axis_count - 1.0) / 2.0

	match ordering:
		OrderingMode.REVERSE:
			slots.reverse()
		OrderingMode.BOTTOM_UP:
			slots.sort_custom(func(a, b): return a.y > b.y if a.y != b.y else a.x < b.x)
		OrderingMode.SPIRAL:
			slots.sort_custom(
				func(a, b):
					var pos_a = Vector2(a.x + (0.5 if _is_row_staggered(int(a.y)) else 0.0), a.y)
					var pos_b = Vector2(b.x + (0.5 if _is_row_staggered(int(b.y)) else 0.0), b.y)
					return pos_a.distance_to(Vector2(center_p, center_s)) < pos_b.distance_to(Vector2(center_p, center_s))
			)
	return slots


func _draw() -> void:
	if not Engine.is_editor_hint() or not show_debug_grid:
		return
	var params = _get_grid_params()
	var slots = _get_sorted_slots()
	var child_count = params.children.size()

	for s in range(secondary_axis_count):
		var is_stag = _is_row_staggered(s)
		var row_count = primary_axis_count - 1 if is_stag else primary_axis_count
		var stagger = 0.5 if is_stag else 0.0
		var row_start = params.origin + (params.dir_p * stagger * params.unit_p) + (params.dir_s * s * params.unit_s)
		if row_count > 0:
			draw_line(row_start, row_start + (params.dir_p * (row_count - 1) * params.unit_p), Color.BLACK, 1.0)

		for p in range(row_count):
			var pos = row_start + (params.dir_p * p * params.unit_p)
			var is_filled = slots.slice(0, child_count).has(Vector2(p, s))
			draw_circle(pos, 4.0 if is_filled else 3.0, Color.RED if is_filled else Color.CORNFLOWER_BLUE)

	if grid_type == GridType.ORTHOGONAL:
		for p in range(primary_axis_count):
			var col_start = params.origin + (params.dir_p * p * params.unit_p)
			var col_end = col_start + (params.dir_s * (secondary_axis_count - 1) * params.unit_s)
			draw_line(col_start, col_end, Color.BLACK, 1.0)
