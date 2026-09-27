extends RefCounted
## NON-CANONICAL diagnostic choices over normal authoritative commands.
## Projection ranking is read-only; all actual acquisition and placement uses RulesEngine.

const Intent = preload("res://tests/fixtures/phase_six_factory.gd")
const UNPLACED: Array[int] = [TileLocationState.Kind.BAG, TileLocationState.Kind.ACTIVE_HAND,
	TileLocationState.Kind.RESERVE, TileLocationState.Kind.INSPECTED]
var _content: ContentRegistry
var prefer_market: bool = false
var placements: int = 0
var cycles: int = 0
var candidates: int = 0
var draft_choices: Array[Dictionary] = []
var tile_choices: Array[Dictionary] = []
var checkpoints: Dictionary = {}
var _chosen_designs: Array[String] = []


func _init(content: ContentRegistry) -> void:
	_content = content


func start(seed_value: int) -> RunState:
	var state: RunState = HomesteadRunFactory.create(seed_value, _content)
	_drain(state)
	capture_composition(state, "opening")
	return state


func play_one(state: RunState) -> bool:
	assert(state.phase == GamePhase.Type.TURN_INPUT)
	var best: PlacementOption = null
	var best_rank: Array[int] = []
	var previous_exits: int = _open_exits(TopologyService.rebuild(state))
	for copy_id: int in state.expansion.hand:
		if copy_id == 0:
			continue
		for option: PlacementOption in PlacementQueryService.query_for_copy(state, _content, copy_id):
			candidates += 1
			var rank: Array[int] = _rank(state, option, previous_exits)
			if best == null or _less(rank, best_rank):
				best = option
				best_rank = rank
	if best == null:
		var cycle: ValidationResult = RulesEngine.execute(state, _content, CycleDeadHandCommand.new())
		assert(cycle.is_valid, cycle.user_message)
		cycles += 1
		assert(cycles < 100, "Diagnostic cannot spin on a dead hand")
		return false
	var outgoing_act: int = state.expansion.current_act
	var accepted: ValidationResult = RulesEngine.execute(state, _content, Intent.command(best))
	assert(accepted.is_valid, accepted.user_message + str(accepted.debug_details))
	placements += 1
	_drain(state)
	if state.expansion.current_act != outgoing_act:
		capture_composition(state, "act_%d_entry" % state.expansion.current_act)
	elif state.expansion.current_act == 1 and state.expansion.normal_placements in [6, 12]:
		capture_composition(state, "act_1_placement_%d" % state.expansion.normal_placements)
	elif state.expansion.current_act == 2 and state.expansion.normal_placements == 11:
		capture_composition(state, "act_2_midpoint")
	return true


func _drain(state: RunState) -> void:
	var guard: int = 0
	while state.pending_choice != null:
		guard += 1
		assert(guard < 100)
		var choice: PendingChoice = state.pending_choice
		var command: PlayerCommand
		var choice_count_before: int = tile_choices.size()
		match choice.kind:
			&"tile_draft":
				if String(choice.context.get("draft_type", "")) == "act_entry":
					var label: String = "act_%d_end_before_entry_draft" % (int(choice.context.get("act", state.expansion.current_act)) - 1)
					if not checkpoints.has(label):
						capture_composition(state, label)
				var selected: int = _tile_choice_index(state, choice)
				_record_tile_choice(state, choice, selected, true)
				command = ResolveTileDraftCommand.new(choice.choice_id, selected, state.expansion.state_revision)
			&"specialist_assignment":
				command = ResolveSpecialistAssignmentCommand.new(choice.choice_id, 0, -1, 0, true)
			&"specialist_training":
				command = ResolveSpecialistTrainingCommand.new(choice.choice_id, StringName(choice.options[0]["role_definition_id"]))
			&"specialist_relay":
				command = ResolveRelayCommand.new(choice.choice_id)
			&"grand_survey":
				command = ResolveGrandSurveyCommand.new(choice.choice_id, 0, true)
			&"compass":
				command = ResolveCompassCommand.new(choice.choice_id, int(choice.options[0]["tile_copy_id"]))
			_:
				assert(RewardCommands.KINDS.has(choice.kind), "Unhandled diagnostic choice")
				var selected: int = 0
				if choice.kind in [&"tile_reward", &"masterwork"]:
					selected = _tile_choice_index(state, choice)
					_record_tile_choice(state, choice, selected, false)
				elif choice.kind == &"relic_replacement":
					for index: int in range(choice.options.size()):
						if bool(choice.options[index].get("decline", false)):
							selected = index
				command = ResolveRewardCommand.new(choice.choice_id, selected)
		var accepted: ValidationResult = RulesEngine.execute(state, _content, command)
		assert(accepted.is_valid, accepted.user_message + str(accepted.debug_details))
		if tile_choices.size() > choice_count_before:
			var row: Dictionary = tile_choices.back()
			row["selected_copies_after"] = acquired_count(state, StringName(row["selected"]))
			row["quantity_acquired"] = int(row["selected_copies_after"]) - int(row["selected_copies_before"])
			row["market_copies_after"] = acquired_count(state, &"tile.development.market")
			if choice.kind == &"tile_draft":
				draft_choices[-1] = row.duplicate(true)


func _tile_choice_index(state: RunState, choice: PendingChoice) -> int:
	if prefer_market and state.expansion.current_act == 2 and acquired_count(state, &"tile.development.market") < 2:
		for index: int in range(choice.options.size()):
			if String(choice.options[index].get("definition_id", "")) == "tile.development.market":
				return index
	return 0 # Persisted RNG offer order; no second draw, weighting or reroll.


func _record_tile_choice(state: RunState, choice: PendingChoice, selected: int, draft: bool) -> void:
	var offered: Array[String] = []
	for option: Dictionary in choice.options:
		offered.append(String(option.get("definition_id", "")))
	var design: String = offered[selected]
	var row: Dictionary = {"choice_id": choice.choice_id, "kind": String(choice.kind),
		"draft_type": String(choice.context.get("draft_type", "")),
		"act": int(choice.context.get("act", state.expansion.current_act)),
		"placement_index": int(choice.context.get("placement_index", state.expansion.normal_placements)),
		"draft_sequence": int(choice.context.get("draft_sequence", -1)),
		"offered": offered, "selected": design,
		"repeated_design_choice": _chosen_designs.has(design),
		"market_copies_before": acquired_count(state, &"tile.development.market"),
		"selected_copies_before": acquired_count(state, StringName(design))}
	_chosen_designs.append(design)
	tile_choices.append(row)
	if draft:
		draft_choices.append(row.duplicate(true))


static func acquired_count(state: RunState, definition_id: StringName, through_act: int = 3) -> int:
	var count: int = 0
	for copy: TileCopyState in state.tile_copies:
		if copy.definition_id == definition_id and copy.acquired_act <= through_act:
			count += 1
	return count


func capture_composition(state: RunState, label: String) -> void:
	var core: Array[StringName] = []
	for entry: StartingBagEntry in _content.get_config().starting_bag:
		core.append(entry.definition_id)
	var definitions: Dictionary = {}
	var sources: Dictionary = {}
	var zones: Dictionary = {}
	var ids: Array[int] = []
	var core_copies: int = 0
	var choice_copies: int = 0
	var development_copies: int = 0
	var transformation_copies: int = 0
	for location: TileLocationState in state.tile_locations:
		if int(location.kind) not in UNPLACED:
			continue
		var copy: TileCopyState = PhysicalTileRules.find_copy(state, location.tile_copy_id)
		var definition: TileDefinition = _content.get_tile(copy.definition_id)
		ids.append(copy.tile_copy_id)
		_increment(definitions, String(copy.definition_id))
		_increment(sources, String(copy.acquisition_source))
		_increment(zones, str(location.kind))
		if core.has(copy.definition_id):
			core_copies += 1
		if copy.acquisition_source != &"homestead_starting_bag" and copy.acquisition_source != &"emergency_replenishment":
			choice_copies += 1
		if definition.tile_class in [DomainTypes.TileClass.DEVELOPMENT, DomainTypes.TileClass.UPGRADE]:
			development_copies += 1
		if definition.tile_class == DomainTypes.TileClass.TRANSFORMATION:
			transformation_copies += 1
	ids.sort()
	checkpoints[label] = {"act": state.expansion.current_act, "normal_placements": state.expansion.normal_placements,
		"phase": state.phase, "unplaced_copies": ids.size(), "distinct_designs": definitions.size(),
		"definition_counts": definitions, "acquisition_source_counts": sources, "zone_counts": zones,
		"core_design_copies": core_copies, "noncore_design_copies": ids.size() - core_copies,
		"choice_acquired_copies": choice_copies, "development_upgrade_copies": development_copies,
		"transformation_copies": transformation_copies,
		"development_transformation_share": float(development_copies + transformation_copies) / maxi(ids.size(), 1),
		"physical_copy_ids": ids}


static func _increment(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _rank(state: RunState, option: PlacementOption, previous_exits: int) -> Array[int]:
	var projected: RunState
	if option.transformation_plan != null:
		projected = TransformationGeometry.projected(state, _content, option.transformation_plan)
	else:
		projected = RunState.new(0)
		projected.expansion = ExpansionState.new()
		projected.expansion.board.cells = state.expansion.board.cells.duplicate()
		projected.features = FeatureState.new()
		projected.features.components = state.features.components.duplicate()
		projected.features.lineages = state.features.lineages.duplicate()
		if option.placement_mode == DomainTypes.PlacementMode.EXPANSION:
			var definition: TileDefinition = _content.get_tile(PhysicalTileRules.find_copy(state, option.tile_copy_id).definition_id)
			var cell: BoardCellState = BoardCellState.from_definition(definition, option.tile_copy_id,
				option.coordinate, option.rotation, 1, state.expansion.normal_placements + 1)
			projected.expansion.board.cells[option.coordinate] = cell
			for type: int in range(4):
				if TopologyService._has_type(cell, type as DomainTypes.FeatureType):
					var component: FeatureComponentState = FeatureComponentState.new()
					component.component_id = -type - 1
					component.coordinate = option.coordinate
					component.feature_type = type as DomainTypes.FeatureType
					projected.features.components.append(component)
	if option.boundary_direction != -1:
		var at: Vector2i = option.coordinate
		var adjacent: Vector2i = at + BoardState.ORTHOGONAL_OFFSETS[option.boundary_direction]
		projected.expansion.board.cells[at] = TransformationGeometry.copy_cell(projected.expansion.board.get_cell(at))
		projected.expansion.board.cells[adjacent] = TransformationGeometry.copy_cell(projected.expansion.board.get_cell(adjacent))
		RelicGeometry.record_boundary(projected.expansion.board, at, option.boundary_direction)
	projected.features.enclosures = state.features.enclosures.duplicate()
	if option.placement_mode in [DomainTypes.PlacementMode.DEVELOPMENT, DomainTypes.PlacementMode.UPGRADE]:
		var definition: TileDefinition = _content.get_tile(PhysicalTileRules.find_copy(state, option.tile_copy_id).definition_id)
		if definition.development_host_kind == &"enclosure":
			var enclosure: EnclosureState = EnclosureState.new()
			enclosure.enclosure_id = -1
			enclosure.coordinate = option.coordinate
			enclosure.stage = definition.development_stage
			enclosure.development_tile_copy_id = option.tile_copy_id
			projected.features.enclosures.append(enclosure)
	var completions: int = EnclosureService.capture(projected).size()
	var existing_exits: int = 0
	var new_exits: int = 0
	for feature: CurrentFeature in TopologyService.rebuild(projected):
		if feature.feature_type == DomainTypes.FeatureType.RIVER:
			continue
		var parents: Array[int] = LineageService._lineage_ids(projected, feature)
		var changed: bool = parents.is_empty()
		for parent_id: int in parents:
			if not state.features.lineage(parent_id).completed:
				changed = true
		for component_id: int in feature.component_ids:
			if component_id < 0:
				changed = true
		if feature.open_exits == 0 and changed:
			completions += 1
		if parents.is_empty():
			new_exits += feature.open_exits
		else:
			existing_exits += feature.open_exits
	return [-completions, existing_exits - previous_exits, new_exits]


static func _open_exits(features: Array[CurrentFeature]) -> int:
	var total: int = 0
	for feature: CurrentFeature in features:
		if feature.feature_type != DomainTypes.FeatureType.RIVER:
			total += feature.open_exits
	return total


static func _less(left: Array[int], right: Array[int]) -> bool:
	for index: int in range(left.size()):
		if left[index] != right[index]:
			return left[index] < right[index]
	return false

