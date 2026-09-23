class_name FeatureResolutionService
extends RefCounted
## Synchronous feature and economic topology boundary, before hand refill, including fully committed Transformations.


static func initialize(state: RunState) -> void:
	assert(state.features == null and state.expansion != null)
	state.features = FeatureState.new()
	for coordinate: Vector2i in state.expansion.board.sorted_coordinates():
		TopologyService.add_cell_components(state, state.expansion.board.get_cell(coordinate))
	resolve(state)


static func resolve(state: RunState, source_id: int = 0) -> void:
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	assert(LineageService.validate_rebuild(state, current).is_valid)
	LineageService.reconcile(state, current, source_id)
	DevelopmentService.remap_hosts(state, current)
	if state.trade != null:
		TradeNetworkService.reconcile(state, source_id)
	FeatureScoringService.resolve(state, current, source_id)


static func has_resolution_capacity(state: RunState) -> bool:
	# Bound all IDs/events and base gains for one placement, including enclosure peers.
	# This is a representational guard, not a gameplay limit or optimization.
	var squares: int = state.expansion.board.cells.size() + 1
	var id_budget: int = squares * 96 + state.features.enclosures.size() * 8 + 16
	var gain_budget: int = squares * squares * 32 + squares * 32 + state.features.enclosures.size() * 24
	if state.next_runtime_id > RunIdAllocator.EXHAUSTED_CURSOR - id_budget:
		return false
	for value: int in state.features.tracks.values:
		if value > 9223372036854775807 - gain_budget:
			return false
	return true
