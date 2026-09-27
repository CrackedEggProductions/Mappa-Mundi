extends SceneTree
## NON-CANONICAL Market access and representative inventory measurement.
## Runs genuine commands; never injects Markets, changes Charters or edits live state.
## godot --headless --path . --script res://tests/scenarios/draft_access_diagnostic.gd -- 30 1 3

const Policy = preload("res://tests/scenarios/draft_diagnostic_policy.gd")
var _content: ContentRegistry


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_content = ContentRegistry.new()
	assert(_content.load_phase_nine().is_valid)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var required: int = int(args[0]) if args.size() > 0 else 30
	var first_seed: int = int(args[1]) if args.size() > 1 else 1
	var full_runs: int = int(args[2]) if args.size() > 2 else 3
	assert(required > 0 and full_runs >= 0)
	var started: int = Time.get_ticks_msec()
	var rows: Array[Dictionary] = []
	var entry_rows: Array[Dictionary] = []
	var seed_value: int = first_seed
	while rows.size() < required:
		assert(seed_value < first_seed + required * 20, "Report insufficient natural Market Towns selections rather than editing the Charter")
		var policy: RefCounted = Policy.new(_content)
		policy.prefer_market = true
		var state: RunState = policy.start(seed_value)
		while state.expansion.current_act == 1:
			policy.play_one(state)
		entry_rows.append({"seed": seed_value, "act_two_charter": String(state.charters.act_two_id),
			"entry_markets_acquired": Policy.acquired_count(state, &"tile.development.market")})
		if state.charters.act_two_id == &"charter.a2_market_towns":
			var entry_count: int = Policy.acquired_count(state, &"tile.development.market")
			while state.expansion.current_act == 2:
				policy.play_one(state)
			var row: Dictionary = market_row(seed_value, state, policy, entry_count)
			rows.append(row)
			print("MARKET TOWNS SAMPLE: ", JSON.stringify(row))
		else:
			print("MARKET ENTRY SCREEN: seed=%d charter=%s" % [seed_value, state.charters.act_two_id])
		seed_value += 1
	var representative: Array[Dictionary] = []
	for run_seed: int in range(first_seed, first_seed + full_runs):
		var policy: RefCounted = Policy.new(_content)
		var state: RunState = policy.start(run_seed)
		while state.phase != GamePhase.Type.RUN_COMPLETE:
			policy.play_one(state)
		assert(policy.placements == 66)
		var row: Dictionary = {"seed": run_seed, "placements": policy.placements,
			"draft_choices": policy.draft_choices, "checkpoints": policy.checkpoints,
			"score": state.final_result.score, "victory_result": String(state.final_result.victory_result),
			"fingerprint": StateNormalizer.fingerprint(state)}
		representative.append(row)
		print("REPRESENTATIVE FULL RUN: ", JSON.stringify(row))
	var report: Dictionary = {"rules_version": BuildVersions.GAME_RULES_VERSION,
		"canonical_balance_rule": false, "diagnostic_policy_version": 2,
		"policy": "Same closure-first legal-option ranking as Act-I diagnostic. For Market sample only, select Market whenever present in an Act-II tile offer until two copies have actually been acquired; otherwise first persisted option. Never inject a tile or select a Charter. Representative full runs use first persisted offers throughout.",
		"market_towns_summary": summarize_market(rows), "market_towns_rows": rows,
		"all_act_two_entries_screened": entry_rows, "seeds_screened": entry_rows.size(),
		"representative_full_runs": representative,
		"elapsed_seconds": (Time.get_ticks_msec() - started) / 1000.0}
	var path: String = "res://builds/draft-cadence-access-%d-%d.json" % [first_seed, required]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "\t", true) + "\n")
	file.close()
	print("MARKET ACCESS RESULT: ", JSON.stringify(report["market_towns_summary"]))
	print("DIAGNOSTIC FILE: ", path)
	quit(0)


static func market_row(seed_value: int, state: RunState, policy: RefCounted, entry_count: int) -> Dictionary:
	var entry_offers: int = 0
	var entry_visible: int = 0
	var all_visible: int = 0
	var offers: Array[Dictionary] = []
	var acquisitions: Array[Dictionary] = []
	for choice: Dictionary in policy.tile_choices:
		if int(choice["act"]) != 2:
			continue
		var visible: bool = choice["offered"].has("tile.development.market")
		if choice["draft_type"] == "act_entry":
			entry_offers += 1
			if visible:
				entry_visible += 1
		if visible:
			all_visible += 1
		offers.append(choice)
		if choice["selected"] == "tile.development.market":
			acquisitions.append({"draft_type": choice["draft_type"], "kind": choice["kind"],
				"placement_index": choice["placement_index"], "draft_sequence": choice["draft_sequence"],
				"quantity": choice["quantity_acquired"], "total_acquired": choice["market_copies_after"]})
	return {"seed": seed_value, "entry_draft_offers": entry_offers,
		"entry_offers_showing_market": entry_visible, "entry_market_copies_acquired": entry_count,
		"act_two_offers_showing_market": all_visible,
		"markets_acquired_by_end_act_two": Policy.acquired_count(state, &"tile.development.market", 2),
		"market_acquisition_timing": acquisitions, "act_two_tile_offers": offers,
		"checkpoints": policy.checkpoints, "fingerprint": StateNormalizer.fingerprint(state)}


static func summarize_market(rows: Array[Dictionary]) -> Dictionary:
	var one_visible: int = 0
	var two_visible: int = 0
	var one_entry: int = 0
	var two_entry: int = 0
	var one_end: int = 0
	var two_end: int = 0
	var visibility_histogram: Dictionary = {}
	var acquisition_histogram: Dictionary = {}
	var first_timing: Dictionary = {}
	var second_timing: Dictionary = {}
	for row: Dictionary in rows:
		var visible: int = row["entry_offers_showing_market"]
		var at_entry: int = row["entry_market_copies_acquired"]
		var at_end: int = row["markets_acquired_by_end_act_two"]
		one_visible += int(visible >= 1)
		two_visible += int(visible >= 2)
		one_entry += int(at_entry >= 1)
		two_entry += int(at_entry >= 2)
		one_end += int(at_end >= 1)
		two_end += int(at_end >= 2)
		Policy._increment(visibility_histogram, str(visible))
		Policy._increment(acquisition_histogram, str(at_end))
		var first_recorded: bool = false
		var second_recorded: bool = false
		for acquisition: Dictionary in row["market_acquisition_timing"]:
			var timing: String = "entry" if acquisition["draft_type"] == "act_entry" else "placement_%d" % int(acquisition["placement_index"])
			if not first_recorded and int(acquisition["total_acquired"]) >= 1:
				Policy._increment(first_timing, timing)
				first_recorded = true
			if not second_recorded and int(acquisition["total_acquired"]) >= 2:
				Policy._increment(second_timing, timing)
				second_recorded = true
	return {"samples_with_naturally_selected_market_towns": rows.size(),
		"entry_visibility_at_least_one_percent": 100.0 * one_visible / rows.size(),
		"entry_visibility_at_least_two_percent": 100.0 * two_visible / rows.size(),
		"entry_acquired_at_least_one_percent": 100.0 * one_entry / rows.size(),
		"entry_acquired_at_least_two_percent": 100.0 * two_entry / rows.size(),
		"end_act_two_acquired_at_least_one_percent": 100.0 * one_end / rows.size(),
		"end_act_two_acquired_at_least_two_percent": 100.0 * two_end / rows.size(),
		"entry_market_visibility_histogram": visibility_histogram,
		"end_act_two_market_acquisition_histogram": acquisition_histogram,
		"first_market_acquisition_timing_histogram": first_timing,
		"second_market_acquisition_timing_histogram": second_timing}
