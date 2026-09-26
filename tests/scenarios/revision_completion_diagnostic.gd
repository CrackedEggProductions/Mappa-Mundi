extends SceneTree
## NON-CANONICAL policy measurement, never a balance rule or a human-play claim.
## Run: godot --headless --path . --script res://tests/scenarios/revision_completion_diagnostic.gd -- 100 1

const Intent = preload("res://tests/fixtures/phase_six_factory.gd")
var _content: ContentRegistry


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_content = ContentRegistry.new()
	assert(_content.load_phase_nine().is_valid)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var samples: int = int(args[0]) if args.size() > 0 else 100
	var first_seed: int = int(args[1]) if args.size() > 1 else 1
	var rows: Array[Dictionary] = []
	var started: int = Time.get_ticks_msec()
	for seed_value: int in range(first_seed, first_seed + samples):
		var row: Dictionary = _play(seed_value)
		if row.is_empty():
			printerr("Diagnostic aborted at seed ", seed_value, "; no aggregate can be claimed.")
			quit(1)
			return
		rows.append(row)
		print("ACT I SAMPLE: ", JSON.stringify(row))
	var summary: Dictionary = summarize(rows)
	summary["policy"] = "All legal hand options: most immediate genuine completions, greatest reduction of existing-feature exits, fewest new-feature exits; authoritative query order breaks ties. Decline optional assignment/Relay, finish Grand Survey, decline replacement, otherwise first persisted reward/training option. No Survey/Reserve optimization."
	summary["rules_version"] = BuildVersions.GAME_RULES_VERSION
	summary["diagnostic_policy_version"] = 1
	summary["canonical_balance_rule"] = false
	summary["first_seed"] = first_seed
	summary["last_seed"] = first_seed + samples - 1
	summary["elapsed_seconds"] = (Time.get_ticks_msec() - started) / 1000.0
	summary["rows"] = rows
	var path: String = "res://builds/revision1-completion-%d-%d.json" % [first_seed, samples]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Diagnostic result destination must be writable")
	file.store_string(JSON.stringify(summary, "\t", true) + "\n")
	file.close()
	print("DIAGNOSTIC RESULT: ", JSON.stringify(summarize(rows)))
	print("DIAGNOSTIC FILE: ", path)
	quit(0)


func _play(seed_value: int) -> Dictionary:
	var state: RunState = HomesteadRunFactory.create(seed_value, _content)
	var placements: int = 0
	var cycles: int = 0
	var candidates: int = 0
	while state.expansion.current_act == 1:
		assert(state.phase == GamePhase.Type.TURN_INPUT)
		var best: PlacementOption = null
		var best_rank: Array[int] = []
		var before: Array[CurrentFeature] = TopologyService.rebuild(state)
		var previous_exits: int = _open_exits(before)
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
			continue
		var accepted: ValidationResult = RulesEngine.execute(state, _content, Intent.command(best))
		assert(accepted.is_valid, accepted.user_message + str(accepted.debug_details))
		placements += 1
		_drain(state)
		assert(placements <= 18)
	var counts: Array[int] = [0, 0, 0, 0, 0]
	for completion: FeatureCompletionRecord in state.features.completions:
		if completion.act == 1:
			counts[completion.feature_type if completion.feature_type >= 0 else 4] += 1
	assert(placements == 18 and counts[DomainTypes.FeatureType.RIVER] == 0)
	return {"seed": seed_value, "placements": placements, "completions": counts.reduce(func(a: int, b: int) -> int: return a + b, 0),
		"road": counts[0], "settlement": counts[1], "forest": counts[2], "monastery": counts[4],
		"cycles": cycles, "options_evaluated": candidates, "fingerprint": StateNormalizer.fingerprint(state)}


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


func _drain(state: RunState) -> void:
	var guard: int = 0
	while state.pending_choice != null:
		guard += 1
		assert(guard < 100)
		var choice: PendingChoice = state.pending_choice
		var command: PlayerCommand
		match choice.kind:
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
				if choice.kind == &"relic_replacement":
					for index: int in range(choice.options.size()):
						if bool(choice.options[index].get("decline", false)):
							selected = index
				command = ResolveRewardCommand.new(choice.choice_id, selected)
		var accepted: ValidationResult = RulesEngine.execute(state, _content, command)
		assert(accepted.is_valid, accepted.user_message + str(accepted.debug_details))


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


static func summarize(rows: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {"samples": rows.size()}
	var successful: int = 0
	for row: Dictionary in rows:
		if row.completions > 0:
			successful += 1
	result["percent_with_completion"] = 100.0 * successful / rows.size()
	for key: String in ["completions", "road", "settlement", "forest", "monastery"]:
		var values: Array[int] = []
		var total: int = 0
		var histogram: Dictionary = {}
		for row: Dictionary in rows:
			var value: int = int(row[key])
			values.append(value)
			total += value
			histogram[str(value)] = int(histogram.get(str(value), 0)) + 1
		values.sort()
		var middle: int = floori(values.size() / 2.0)
		var median: float = values[middle]
		if values.size() % 2 == 0:
			median = (values[middle - 1] + values[middle]) / 2.0
		result[key] = {"total": total, "mean": float(total) / rows.size(), "median": median,
			"minimum": values.front(), "maximum": values.back(), "histogram": histogram}
	return result
