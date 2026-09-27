extends SceneTree
## NON-CANONICAL measurement, not a balance rule or a human-play claim.
## godot --headless --path . --script res://tests/scenarios/revision_completion_diagnostic.gd -- 100 1

const Policy = preload("res://tests/scenarios/draft_diagnostic_policy.gd")
var _content: ContentRegistry


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_content = ContentRegistry.new()
	assert(_content.load_phase_nine().is_valid)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var samples: int = int(args[0]) if args.size() > 0 else 100
	var first_seed: int = int(args[1]) if args.size() > 1 else 1
	assert(samples > 0)
	var rows: Array[Dictionary] = []
	var started: int = Time.get_ticks_msec()
	for seed_value: int in range(first_seed, first_seed + samples):
		var row: Dictionary = _play(seed_value)
		rows.append(row)
		print("ACT I SAMPLE: ", JSON.stringify(row))
	var summary: Dictionary = summarize(rows)
	summary["diversity"] = summarize_diversity(rows)
	summary["policy"] = "All legal hand options: most immediate genuine completions, greatest reduction of existing-feature exits, fewest new-feature exits; authoritative query order breaks ties. Choose first persisted Starter/cadence/entry/reward option. Decline assignment/Relay, finish Grand Survey, decline replacement. No Survey/Reserve optimization."
	summary["rules_version"] = BuildVersions.GAME_RULES_VERSION
	summary["diagnostic_policy_version"] = 2
	summary["canonical_balance_rule"] = false
	summary["first_seed"] = first_seed
	summary["last_seed"] = first_seed + samples - 1
	summary["elapsed_seconds"] = (Time.get_ticks_msec() - started) / 1000.0
	summary["rows"] = rows
	var path: String = "res://builds/draft-cadence-completion-%d-%d.json" % [first_seed, samples]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(summary, "\t", true) + "\n")
	file.close()
	print("DIAGNOSTIC RESULT: ", JSON.stringify(summarize(rows)))
	print("DIVERSITY RESULT: ", JSON.stringify(summary["diversity"]))
	print("DIAGNOSTIC FILE: ", path)
	quit(0)


func _play(seed_value: int) -> Dictionary:
	var policy: RefCounted = Policy.new(_content)
	var state: RunState = policy.start(seed_value)
	while state.expansion.current_act == 1:
		policy.play_one(state)
	var counts: Array[int] = [0, 0, 0, 0, 0]
	for completion: FeatureCompletionRecord in state.features.completions:
		if completion.act == 1:
			counts[completion.feature_type if completion.feature_type >= 0 else 4] += 1
	assert(policy.placements == 18 and counts[DomainTypes.FeatureType.RIVER] == 0)
	var drafts: Array[Dictionary] = []
	var starter_offer: Array = []
	var starter_selected: String = ""
	for choice: Dictionary in policy.draft_choices:
		if int(choice["act"]) != 1:
			continue
		drafts.append(choice)
		if choice["draft_type"] == "starter":
			starter_offer = choice["offered"].duplicate()
			starter_selected = choice["selected"]
	assert(starter_offer.size() == 3, "Sample must include the actual persisted Starter Draft")
	var profile: Dictionary = {}
	var noncore: Dictionary = {}
	var core: Array[StringName] = []
	for entry: StartingBagEntry in _content.get_config().starting_bag:
		core.append(entry.definition_id)
	for copy: TileCopyState in state.tile_copies:
		if copy.acquired_act != 1 or not _content.get_tile(copy.definition_id).player_drawable:
			continue
		Policy._increment(profile, String(copy.definition_id))
		if not core.has(copy.definition_id):
			Policy._increment(noncore, String(copy.definition_id))
	return {"seed": seed_value, "placements": policy.placements,
		"completions": counts.reduce(func(a: int, b: int) -> int: return a + b, 0),
		"road": counts[0], "settlement": counts[1], "forest": counts[2], "monastery": counts[4],
		"cycles": policy.cycles, "options_evaluated": policy.candidates,
		"starter_offer": starter_offer, "starter_selected": starter_selected,
		"draft_choices": drafts, "act_1_acquired_profile": profile,
		"noncore_acquired_profile": noncore, "checkpoints": policy.checkpoints.duplicate(true),
		"fingerprint": StateNormalizer.fingerprint(state)}


static func summarize_diversity(rows: Array[Dictionary]) -> Dictionary:
	var triples: Dictionary = {}
	var ordered_triples: Dictionary = {}
	var starter_offered_frequency: Dictionary = {}
	var starter_selected_frequency: Dictionary = {}
	var profiles: Dictionary = {}
	var acquired_design_frequency: Dictionary = {}
	var chosen_design_frequency: Dictionary = {}
	var noncore_variety: Dictionary = {}
	var repeated_choices: int = 0
	var total_choices: int = 0
	for row: Dictionary in rows:
		var triple: Array = row["starter_offer"].duplicate()
		Policy._increment(ordered_triples, JSON.stringify(triple))
		triple.sort()
		Policy._increment(triples, JSON.stringify(triple))
		for design: String in triple:
			Policy._increment(starter_offered_frequency, design)
		Policy._increment(starter_selected_frequency, row["starter_selected"])
		Policy._increment(profiles, JSON.stringify(row["act_1_acquired_profile"], "", true))
		for design: String in row["act_1_acquired_profile"]:
			Policy._increment(acquired_design_frequency, design)
		Policy._increment(noncore_variety, str(row["noncore_acquired_profile"].size()))
		for choice: Dictionary in row["draft_choices"]:
			total_choices += 1
			Policy._increment(chosen_design_frequency, choice["selected"])
			if choice["repeated_design_choice"]:
				repeated_choices += 1
	return {"distinct_starter_offer_triples_unordered": triples.size(),
		"distinct_starter_offer_triples_ordered": ordered_triples.size(),
		"starter_offered_design_frequency": starter_offered_frequency,
		"starter_selected_design_frequency": starter_selected_frequency,
		"distinct_act_1_acquired_profiles": profiles.size(),
		"runs_acquiring_each_design": acquired_design_frequency,
		"chosen_draft_design_frequency": chosen_design_frequency,
		"noncore_distinct_designs_per_run_histogram": noncore_variety,
		"total_draft_choices": total_choices, "repeated_design_choices": repeated_choices,
		"repeated_design_choice_percent": 100.0 * repeated_choices / maxi(total_choices, 1)}


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
