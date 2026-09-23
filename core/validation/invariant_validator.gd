class_name InvariantValidator
extends RefCounted
## Invariant boundary. Subsystem checks are enabled only when their state exists.


static func validate(state: RunState, content: ContentRegistry) -> InvariantReport:
	var report: InvariantReport = InvariantReport.new()
	if state == null:
		report.add(&"missing_state", "RunState is required.")
		return report
	_validate_metadata(state, report)
	if content == null or not content.is_loaded():
		report.add(&"missing_content", "Static definitions must be loaded before validating a run.")
		return report
	var ids: Array[int] = []
	for tile: TileCopyState in state.tile_copies:
		if tile == null:
			report.add(&"missing_tile", "Null physical tile in registry.")
			continue
		if tile.tile_copy_id <= 0 or tile.tile_copy_id in ids:
			report.add(&"invalid_runtime_id", "Physical tile IDs must be positive and unique.", tile.tile_copy_id)
		ids.append(tile.tile_copy_id)
		if state.id_allocator != null and tile.tile_copy_id >= state.next_runtime_id:
			report.add(&"id_cursor_collision", "Next ID must exceed every represented entity ID.", tile.tile_copy_id)
		if content.get_tile(tile.definition_id) == null:
			report.add(&"unknown_definition", "Physical tile's static definition cannot be resolved.", tile.tile_copy_id)
		if tile.acquired_act < 1 or tile.acquired_act > 3:
			report.add(&"invalid_acquisition_act", "Acquisition Act must be within the three alpha Acts.", tile.tile_copy_id)
		if String(tile.acquisition_source).strip_edges().is_empty():
			report.add(&"missing_acquisition_source", "Acquisition source must be a stable nonblank ID.", tile.tile_copy_id)
	_validate_locations(state, ids, report)
	if state.expansion != null:
		ExpansionInvariantValidator.validate(state, content, report)
	if state.features != null and report.is_valid:
		FeatureInvariantValidator.validate(state, content, report)
	if state.features != null and report.is_valid:
		DevelopmentInvariantValidator.validate(state, content, report)
	if state.trade != null and report.is_valid:
		TradeInvariantValidator.validate(state, report)
	return report


static func _validate_metadata(state: RunState, report: InvariantReport) -> void:
	if state.save_schema_version != BuildVersions.SAVE_SCHEMA_VERSION \
			or state.game_rules_version != BuildVersions.GAME_RULES_VERSION \
			or state.implementation_spec_version != BuildVersions.IMPLEMENTATION_SPEC_VERSION:
		report.add(&"incompatible_version", "Run metadata differs from the supported schema/rules/spec.")
	if state.godot_version != BuildVersions.godot_version():
		report.add(&"incompatible_engine", "RNG continuation is only verified for this exact Godot build.")
	if state.expansion == null and state.phase != GamePhase.Type.SETUP:
		report.add(&"unsupported_phase", "Phase 1 represents SETUP foundations only, not a playable turn.")
	if state.id_allocator == null:
		report.add(&"missing_allocator", "A run must own an ID allocator.")
	elif state.next_runtime_id < 1:
		report.add(&"invalid_id_cursor", "Next runtime ID must be positive.")
	if state.rng == null:
		report.add(&"missing_rng", "A run must own its deterministic RNG stream.")
	elif state.rng.operation_count < 0:
		report.add(&"invalid_rng_counter", "RNG operation counter must be nonnegative.")
	# Seed/state are signed 64-bit typed properties owned by one RNG; not duplicated.
	# No rule can infer arbitrary saved RNG provenance from a state integer alone.


static func _validate_locations(state: RunState, ids: Array[int], report: InvariantReport) -> void:
	var located_ids: Array[int] = []
	for location: TileLocationState in state.tile_locations:
		if location == null:
			report.add(&"missing_location", "Null physical location record.")
			continue
		var tile_id: int = location.tile_copy_id
		if tile_id not in ids:
			report.add(&"unresolved_location", "Location references an absent physical tile.", tile_id)
		if tile_id in located_ids:
			report.add(&"duplicate_location", "Physical tile exists in more than one location record.", tile_id)
		located_ids.append(tile_id)
		if location.kind not in TileLocationState.Kind.values():
			report.add(&"invalid_location_kind", "Unrecognized physical tile location kind.", tile_id)
		elif state.expansion == null and location.kind != TileLocationState.Kind.REMOVED_FROM_RUN:
			report.add(&"unsupported_location", "This zone requires a later-phase container/host implementation.", tile_id)
	for tile_id: int in ids:
		if tile_id not in located_ids:
			report.add(&"unlocated_tile", "Physical tile must have exactly one location record.", tile_id)


static func assert_valid(state: RunState, content: ContentRegistry) -> bool:
	var report: InvariantReport = validate(state, content)
	if not report.is_valid:
		var seed_detail: String = "unavailable"
		if state != null and state.rng != null:
			seed_detail = str(state.original_seed)
		var diagnostic: String = "Mappa Mundi invariant failure; seed=%s\n%s" % [seed_detail, report.describe()]
		push_error(diagnostic)
		assert(false, diagnostic)
	return report.is_valid
