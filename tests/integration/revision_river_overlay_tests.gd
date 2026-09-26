extends "res://tests/framework/test_suite.gd"
## Real generated geography, physical overlay commands and direct saved snapshots.

const HAMLET: StringName = &"tile.riverside_hamlet"
const WOODLAND: StringName = &"tile.woodland_river"
const Intent = preload("res://tests/fixtures/phase_six_factory.gd")
const Acquisition = preload("res://tests/fixtures/phase_five_factory.gd")


func tests() -> Array[Callable]:
	return [hamlet_content, woodland_content, hamlet_run_banks_only, woodland_bends_only,
		hamlet_preserves_river_and_slot, woodland_preserves_river_and_slot,
		hamlet_second_bank_preserves_first, hamlet_incompatible_neighbor_rejected,
		woodland_incompatible_neighbor_rejected, hamlet_matching_bank_connects,
		woodland_matching_bank_connects, hamlet_later_completion_and_support,
		woodland_later_completion_and_ecology, port_on_hamlet_counts_separately,
		bridge_counts_as_interaction, setup_and_ferry_are_not_interactions,
		removed_interaction_keeps_history, replaced_bank_effect_is_not_active,
		overlay_round_trip, query_preserves_rng_and_fingerprint]


func _content() -> ContentRegistry:
	var content: ContentRegistry = ContentRegistry.new()
	var result: ValidationResult = content.load_phase_nine()
	assert(result.is_valid, result.user_message)
	return content


func _new(content: ContentRegistry) -> RunState:
	return HomesteadRunFactory.create(123, content)


func _options(state: RunState, content: ContentRegistry, id: StringName) -> Array[PlacementOption]:
	return PlacementQueryService.query_for_copy(state, content, Acquisition.acquire_hand(state, id))


func _commit(state: RunState, content: ContentRegistry, option: PlacementOption) -> void:
	var result: ValidationResult = RulesEngine.execute(state, content, Intent.command(option))
	assert(result.is_valid, result.user_message)
	var guard: int = 0
	while state.pending_choice != null:
		guard += 1
		assert(guard < 30)
		var choice: PendingChoice = state.pending_choice
		var command: PlayerCommand
		if choice.kind == &"specialist_assignment":
			command = ResolveSpecialistAssignmentCommand.new(choice.choice_id, 0, -1, 0, true)
		elif choice.kind == &"specialist_relay":
			command = ResolveRelayCommand.new(choice.choice_id)
		elif choice.kind == &"specialist_training":
			command = ResolveSpecialistTrainingCommand.new(choice.choice_id, StringName(choice.options[0]["role_definition_id"]))
		elif choice.kind == &"grand_survey":
			command = ResolveGrandSurveyCommand.new(choice.choice_id, 0, true)
		else:
			command = ResolveRewardCommand.new(choice.choice_id, 0)
		assert(RulesEngine.execute(state, content, command).is_valid)


func _feature(state: RunState, at: Vector2i, type: int) -> CurrentFeature:
	for feature: CurrentFeature in TopologyService.rebuild(state):
		if feature.feature_type == type and at in feature.coordinates:
			return feature
	return null


func _content_case(id: StringName, mode: StringName) -> bool:
	var tile: TileDefinition = _content().get_tile(id)
	expect_equal(tile.tile_class, DomainTypes.TileClass.TRANSFORMATION, "Interaction is an occupied Transformation")
	expect_equal(tile.transformation_kind, mode, "Stable explicit behavior")
	expect_equal(tile.unlock_act, 1, "Available in Act I")
	expect_equal(tile.reward_class, DomainTypes.RewardClass.SPECIALIZED_EXPANSION, "Specialized Masterwork eligibility retained")
	expect_equal(tile.normal_reward_copy_count, 2, "Normal reward gives two copies")
	expect_true(tile.canonical_edges.is_empty(), "Overlay cannot invent an empty-square River base")
	return true


func hamlet_content() -> bool:
	return _content_case(HAMLET, &"riverside_hamlet")


func woodland_content() -> bool:
	return _content_case(WOODLAND, &"woodland_river")


func hamlet_run_banks_only() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new(content)
	var options: Array[PlacementOption] = _options(state, content, HAMLET)
	expect_true(not options.is_empty(), "Generated Runs provide bank choices")
	for option: PlacementOption in options:
		var cell: BoardCellState = state.expansion.board.get_cell(option.coordinate)
		expect_equal(cell.definition_id, &"tile.river_run", "Hamlet only targets existing straight environmental Runs")
		expect_true(option.rotation % 2 != cell.rotation % 2, "Only lateral bank orientations")
		expect_equal(option.boundary_direction, -1, "Boundary Stones never applies to overlay")
	return true


func woodland_bends_only() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new(content)
	var options: Array[PlacementOption] = _options(state, content, WOODLAND)
	expect_equal(options.size(), 2, "Two generated Bends each provide one Woodland target")
	for option: PlacementOption in options:
		var cell: BoardCellState = state.expansion.board.get_cell(option.coordinate)
		expect_equal(cell.definition_id, &"tile.river_bend", "Woodland only targets environmental Bends")
		expect_equal(option.rotation, cell.rotation, "Bend orientation comes from the existing River")
	return true


func _preserves(id: StringName, type: int) -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new(content)
	var option: PlacementOption = _options(state, content, id)[0]
	var cell: BoardCellState = state.expansion.board.get_cell(option.coordinate)
	var river: FeatureComponentState = state.features.component_at(cell.coordinate, DomainTypes.FeatureType.RIVER)
	var river_id: int = river.component_id
	var base_id: int = cell.base_tile_copy_id
	var before_edges: Array[DomainTypes.EdgeType] = cell.effective_edges.duplicate()
	_commit(state, content, option)
	expect_equal(cell.base_tile_copy_id, base_id, "Overlay retains physical environmental base")
	expect_equal(state.features.component_at(cell.coordinate, DomainTypes.FeatureType.RIVER).component_id, river_id, "River identity preserved")
	for direction: int in range(4):
		if before_edges[direction] == DomainTypes.EdgeType.RIVER:
			expect_equal(cell.effective_edges[direction], DomainTypes.EdgeType.RIVER, "River socket preserved")
	expect_true(state.features.component_at(cell.coordinate, type) != null, "Ordinary component created with Transformation provenance")
	expect_true(cell.developments.is_empty(), "Normal Development slot remains free")
	expect_equal(state.expansion.normal_placements, 1, "Overlay consumes one normal placement")
	expect_equal(_feature(state, cell.coordinate, DomainTypes.FeatureType.RIVER).coordinates.size(), 9, "Connected River size unchanged")
	expect_equal(RiverInteractionService.current_count(state), 1, "Installed overlay counts once")
	expect_equal(RiverInteractionService.creation_count(state), 1, "Creation audit counts once")
	expect_true(FeatureContactService.support_ids(state, _feature(state, cell.coordinate, type), DomainTypes.EdgeType.RIVER).has(base_id), "Same-tile explicit contact includes own River tile")
	expect_true(InvariantValidator.validate(state, content).is_valid, InvariantValidator.validate(state, content).describe())
	return true


func hamlet_preserves_river_and_slot() -> bool:
	return _preserves(HAMLET, DomainTypes.FeatureType.SETTLEMENT)


func woodland_preserves_river_and_slot() -> bool:
	return _preserves(WOODLAND, DomainTypes.FeatureType.FOREST)


func hamlet_second_bank_preserves_first() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new(content)
	var first: PlacementOption = _options(state, content, HAMLET)[0]
	_commit(state, content, first)
	var original: FeatureComponentState = state.features.component_at(first.coordinate, DomainTypes.FeatureType.SETTLEMENT)
	var found: bool = false
	for option: PlacementOption in _options(state, content, HAMLET):
		if option.coordinate == first.coordinate:
			expect_equal(option.rotation, (first.rotation + 2) % 4, "Only remaining Field bank is offered")
			_commit(state, content, option)
			found = true
			break
	expect_true(found, "Opposite bank accepts compatible second Hamlet")
	var cell: BoardCellState = state.expansion.board.get_cell(first.coordinate)
	expect_equal(cell.effective_edges[first.rotation], DomainTypes.EdgeType.SETTLEMENT, "First bank is preserved")
	expect_equal(state.features.component_at(first.coordinate, DomainTypes.FeatureType.SETTLEMENT).component_id, original.component_id, "Same-type Settlement identity is shared")
	expect_equal(RiverInteractionService.current_count(state), 2, "Two separately built physical interactions")
	return true


func _incompatible(id: StringName) -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new(content)
	var option: PlacementOption = _options(state, content, id)[0]
	var change: TransformationChange = option.transformation_plan.changes[0]
	var direction: int = 0
	for index: int in range(4):
		if change.before_edges[index] != change.after_edges[index]:
			direction = index
			break
	var at: Vector2i = option.coordinate + BoardState.ORTHOGONAL_OFFSETS[direction]
	var blocker: int = PhysicalTileRules.acquire(state, &"tile.open_fields", &"scenario_fixture", TileLocationState.Kind.BOARD_BASE)
	state.expansion.board.add_cell(BoardCellState.from_definition(content.get_tile(&"tile.open_fields"), blocker, at, 0, 1, 0))
	var before: String = StateNormalizer.fingerprint(state)
	var result: ValidationResult = RulesEngine.execute(state, content, Intent.command(option))
	expect_true(not result.is_valid, "Occupied incompatible bank rejects command")
	expect_equal(StateNormalizer.fingerprint(state), before, "Invalid bank changes no RNG, events, geometry or physical zones")
	for candidate: PlacementOption in PlacementQueryService.query_for_copy(state, content, option.tile_copy_id):
		expect_true(candidate.coordinate != option.coordinate or candidate.rotation != option.rotation, "Incompatible bank absent from legal query")
	return true


func hamlet_incompatible_neighbor_rejected() -> bool:
	return _incompatible(HAMLET)


func woodland_incompatible_neighbor_rejected() -> bool:
	return _incompatible(WOODLAND)


func _matching(id: StringName, neighbor_id: StringName, edge: int, type: int) -> bool:
	# Query fixture deliberately presents the post-rewrite matching bank; it never commits an invalid board.
	var content: ContentRegistry = _content()
	var state: RunState = _new(content)
	var option: PlacementOption = _options(state, content, id)[0]
	var change: TransformationChange = option.transformation_plan.changes[0]
	var direction: int = change.after_edges.find(edge)
	var at: Vector2i = option.coordinate + BoardState.ORTHOGONAL_OFFSETS[direction]
	var copy_id: int = PhysicalTileRules.acquire(state, neighbor_id, &"scenario_fixture", TileLocationState.Kind.BOARD_BASE)
	var cell: BoardCellState = BoardCellState.from_definition(content.get_tile(neighbor_id), copy_id, at, (direction + 2) % 4, 1, 0)
	state.expansion.board.add_cell(cell)
	TopologyService.add_cell_components(state, cell)
	var found: bool = false
	for candidate: PlacementOption in PlacementQueryService.query_for_copy(state, content, option.tile_copy_id):
		if candidate.coordinate == option.coordinate and candidate.rotation == option.rotation:
			var projected: RunState = TransformationGeometry.projected(state, content, candidate.transformation_plan)
			for feature: CurrentFeature in TopologyService.rebuild(projected):
				if feature.feature_type == type and at in feature.coordinates:
					found = option.coordinate in feature.coordinates
	expect_true(found, "Matching neighbor connects to newly created bank component")
	return true


func hamlet_matching_bank_connects() -> bool:
	return _matching(HAMLET, &"tile.hamlet_edge", DomainTypes.EdgeType.SETTLEMENT, DomainTypes.FeatureType.SETTLEMENT)


func woodland_matching_bank_connects() -> bool:
	return _matching(WOODLAND, &"tile.forest_edge", DomainTypes.EdgeType.FOREST, DomainTypes.FeatureType.FOREST)


func _complete_overlay(id: StringName, cap_id: StringName, type: int) -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new(content)
	var option: PlacementOption = _options(state, content, id)[0]
	_commit(state, content, option)
	var change: TransformationChange = option.transformation_plan.changes[0]
	for direction: int in range(4):
		if change.before_edges[direction] == change.after_edges[direction]:
			continue
		var at: Vector2i = option.coordinate + BoardState.ORTHOGONAL_OFFSETS[direction]
		var found: bool = false
		for cap: PlacementOption in _options(state, content, cap_id):
			if cap.coordinate == at and cap.rotation == (direction + 2) % 4:
				_commit(state, content, cap)
				found = true
				break
		expect_true(found, "Ordinary closure tile can finish new bank geography")
	var feature: CurrentFeature = _feature(state, option.coordinate, type)
	expect_true(state.features.lineage(feature.lineage_id).completed, "New bank feature genuinely completes")
	expect_true(not state.features.lineage(feature.lineage_id).scored_river_ids.is_empty(), "River support/contact is recorded by base scoring")
	for record: FeatureCompletionRecord in state.features.completions:
		expect_true(record.feature_type != DomainTypes.FeatureType.RIVER, "No River completion from overlay or closure")
	return true


func hamlet_later_completion_and_support() -> bool:
	return _complete_overlay(HAMLET, &"tile.hamlet_edge", DomainTypes.FeatureType.SETTLEMENT)


func woodland_later_completion_and_ecology() -> bool:
	return _complete_overlay(WOODLAND, &"tile.forest_edge", DomainTypes.FeatureType.FOREST)


func port_on_hamlet_counts_separately() -> bool:
	var content: ContentRegistry = ContentRegistry.new()
	assert(content.load_phase_six().is_valid)
	var state: RunState = _new(content)
	var option: PlacementOption = _options(state, content, HAMLET)[0]
	_commit(state, content, option)
	state.expansion.current_act = 2 # Controlled Act-aware fixture; transitions tested independently.
	var options: Array[PlacementOption] = _options(state, content, &"tile.development.port")
	var found: bool = false
	for port: PlacementOption in options:
		if port.coordinate == option.coordinate:
			expect_true(port.river_lineage_id != 0, "Same-tile River relationship provides Port eligibility")
			_commit(state, content, port)
			found = true
			break
	expect_true(found, "Hamlet host leaves normal Development slot available")
	expect_equal(RiverInteractionService.current_count(state), 2, "Port and Hamlet are two distinct active objects")
	expect_equal(RiverInteractionService.creation_count(state), 2, "Both creation records persist")
	expect_true(InvariantValidator.validate(state, content).is_valid, InvariantValidator.validate(state, content).describe())
	return true


func bridge_counts_as_interaction() -> bool:
	var content: ContentRegistry = ContentRegistry.new()
	assert(content.load_phase_six().is_valid)
	var state: RunState = _new(content)
	state.expansion.current_act = 3
	var option: PlacementOption = _options(state, content, &"tile.transformation.bridge")[0]
	_commit(state, content, option)
	expect_equal(RiverInteractionService.current_count(state), 1, "Bridge on generated Run counts once")
	expect_equal(RiverInteractionService.creation_count(state), 1, "Bridge creation survives as structured history")
	expect_true(InvariantValidator.validate(state, content).is_valid, InvariantValidator.validate(state, content).describe())
	return true


func setup_and_ferry_are_not_interactions() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new(content)
	expect_equal(RiverInteractionService.current_count(state), 0, "Nine setup River cells are geography, not player interactions")
	expect_true(RelicRules.acquire(state, content, &"relic.ferry_rights").is_valid, "Ferry may be equipped")
	expect_equal(RiverInteractionService.current_count(state), 0, "Passive Ferry connectivity is not an interaction instance")
	expect_equal(RiverInteractionService.creation_count(state), 0, "Setup and Relic acquisition create no interaction history")
	return true


func removed_interaction_keeps_history() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new(content)
	var option: PlacementOption = _options(state, content, HAMLET)[0]
	_commit(state, content, option)
	# Query-only future-removal fixture; no current player command removes overlays.
	PhysicalTileRules.set_location(state, option.tile_copy_id, TileLocationState.Kind.REMOVED_FROM_RUN)
	expect_equal(RiverInteractionService.current_count(state), 0, "Removed object cannot remain active through historical record")
	expect_equal(RiverInteractionService.creation_count(state), 1, "Created-during-run condition retains its audit")
	return true


func replaced_bank_effect_is_not_active() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new(content)
	var option: PlacementOption = _options(state, content, HAMLET)[0]
	_commit(state, content, option)
	state.expansion.board.get_cell(option.coordinate).effective_edges[option.rotation] = DomainTypes.EdgeType.FIELD
	expect_equal(RiverInteractionService.current_count(state), 0, "Historical bank rewrite alone does not prove an active effect")
	expect_equal(RiverInteractionService.creation_count(state), 1, "Historical creation remains")
	return true


func overlay_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new(content)
	_commit(state, content, _options(state, content, HAMLET)[0])
	_commit(state, content, _options(state, content, WOODLAND)[0])
	var encoded: SerializationResult = RunSerializer.serialize(state, content)
	expect_true(encoded.validation.is_valid, encoded.validation.user_message)
	var restored: DeserializationResult = RunSerializer.deserialize(encoded.json_text, content)
	expect_true(restored.validation.is_valid, restored.validation.user_message)
	if restored.state != null:
		expect_equal(StateNormalizer.fingerprint(restored.state), StateNormalizer.fingerprint(state), "Exact overlay/River snapshots restore without replay or RNG")
		expect_equal(RiverInteractionService.current(restored.state), RiverInteractionService.current(state), "Active physical identities and River references survive")
		expect_equal(RiverInteractionService.creation_history(restored.state), RiverInteractionService.creation_history(state), "Structured history survives")
	return true


func query_preserves_rng_and_fingerprint() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new(content)
	var id: int = Acquisition.acquire_hand(state, HAMLET)
	var before: String = StateNormalizer.fingerprint(state)
	TransformationPlacementQuery.query(state, content, id)
	RiverInteractionService.current(state)
	RiverInteractionService.creation_count(state)
	expect_equal(StateNormalizer.fingerprint(state), before, "Queries allocate no runtime IDs, consume no RNG and mutate nothing")
	return true
