class_name RiverInteractionService
extends RefCounted
## Current installed player interactions and persistent creation audit, not River completion.

const DEFINITIONS: Dictionary = {
	&"tile.riverside_hamlet": &"riverside_hamlet",
	&"tile.woodland_river": &"woodland_river",
	&"tile.development.port": &"port",
	&"tile.transformation.bridge": &"bridge",
}


static func current(state: RunState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.expansion == null or state.features == null:
		return result
	for at: Vector2i in state.expansion.board.sorted_coordinates():
		var cell: BoardCellState = state.expansion.board.get_cell(at)
		for value: TransformationState in cell.transformations:
			if value == null or value.definition_id not in DEFINITIONS or not _installed(state, value.tile_copy_id, TileLocationState.Kind.BOARD_TRANSFORMATION):
				continue
			if not _effect_retained(cell, value):
				continue
			var river: FeatureComponentState = state.features.component_at(at, DomainTypes.FeatureType.RIVER)
			if river != null:
				result.append(_entry(value.mode, value.tile_copy_id, at, river.lineage_id))
		for value: DevelopmentState in cell.developments:
			if value != null and value.stage == &"port" and _installed(state, value.tile_copy_id, TileLocationState.Kind.BOARD_DEVELOPMENT):
				var river: FeatureLineageState = state.features.lineage(value.river_lineage_id)
				if river != null and river.feature_type == DomainTypes.FeatureType.RIVER and river.active:
					result.append(_entry(&"port", value.tile_copy_id, at, value.river_lineage_id))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["object_id"] < b["object_id"])
	return result


static func current_count(state: RunState) -> int:
	return current(state).size()


static func creation_count(state: RunState) -> int:
	return creation_history(state).size()


static func creation_history(state: RunState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Array[int] = []
	if state.features == null:
		return result
	for event: FeatureHistoryRecord in state.features.history:
		if event.kind not in [&"transformation_applied", &"development_placed"] or event.source_id in seen:
			continue
		var copy: TileCopyState = PhysicalTileRules.find_copy(state, event.source_id)
		if copy == null or copy.definition_id not in DEFINITIONS:
			continue
		if (copy.definition_id == &"tile.development.port") != (event.kind == &"development_placed"):
			continue
		seen.append(event.source_id)
		result.append({"kind": DEFINITIONS[copy.definition_id], "object_id": event.source_id,
			"event_id": event.event_id, "act": event.act, "placement_index": event.placement_index})
	return result


static func validate(state: RunState, report: InvariantReport) -> void:
	var seen: Array[int] = []
	for value: Dictionary in current(state):
		if value["object_id"] in seen or value["river_ids"].is_empty():
			report.add(&"invalid_river_interaction", "Active River interactions require unique physical objects and River identity.")
		seen.append(value["object_id"])
		for id: int in value["river_ids"]:
			var river: FeatureLineageState = state.features.lineage(id)
			if river == null or not river.active or river.feature_type != DomainTypes.FeatureType.RIVER:
				report.add(&"invalid_river_interaction_target", "River interaction must reference current River geography.")


static func _entry(kind: StringName, id: int, at: Vector2i, river_id: int) -> Dictionary:
	return {"kind": kind, "object_id": id, "coordinate": at, "river_ids": [river_id]}


static func _installed(state: RunState, id: int, kind: TileLocationState.Kind) -> bool:
	for location: TileLocationState in state.tile_locations:
		if location.tile_copy_id == id:
			return location.kind == kind
	return false


static func _effect_retained(cell: BoardCellState, value: TransformationState) -> bool:
	if cell.base_tile_copy_id != value.target_base_copy_id or cell.effective_edges.size() != 4:
		return false
	for change: TransformationChange in value.changes:
		if change == null or change.coordinate != cell.coordinate:
			continue
		if change.before_edges.size() != 4 or change.after_edges.size() != 4:
			return false
		for direction: int in range(4):
			if change.before_edges[direction] != change.after_edges[direction] \
					and cell.effective_edges[direction] != change.after_edges[direction]:
				return false
		return true
	return false
