extends SceneTree
## Seeded physical inventory plus explicit scenario acquisition; no reward system.

const F = preload("res://tests/fixtures/phase_five_factory.gd")
const Scenarios = preload("res://tests/integration/development_scenario_tests.gd")
const Acceptance = preload("res://tests/integration/development_acceptance_tests.gd")

var _finished: bool = false


func _initialize() -> void:
	call_deferred("_run")
	call_deferred("_check_finished")


func _run() -> void:
	var registry: ContentRegistry = F.content()
	var state: RunState = HomesteadRunFactory.create(16, registry)
	state.expansion.current_act = 3 # Controlled unlock context, not an Act transition.
	F.complete_settlement(state, registry)
	F.Previous.Previous.add(state, registry, &"tile.settlement_gate", Vector2i.RIGHT, 2)
	F.Previous.Previous.add(state, registry, &"tile.settlement_gate", Vector2i.ONE)
	F.Previous.Previous.add(state, registry, &"tile.settlement_gate", Vector2i(2, 1), 2)
	var housing: int = F.acquire_hand(state, &"tile.development.housing")
	var options: Array[PlacementOption] = F.options(state, registry, housing)
	var selected: PlacementOption = null
	for option: PlacementOption in options:
		if option.coordinate == Vector2i.ZERO:
			selected = option
	assert(selected != null)
	print("DEMO physical Housing in hand=%d; legal intents=%d; selected host=%d" % [housing, options.size(), selected.host_lineage_id])
	assert(RulesEngine.execute(state, registry, F.command(selected)).is_valid)
	assert(F.play(state, registry, &"tile.development.market", Vector2i.UP) > 0)
	var original: String = StateNormalizer.fingerprint(state)
	var saved: SerializationResult = RunSerializer.serialize(state, registry)
	assert(saved.validation.is_valid)
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, registry)
	assert(loaded.validation.is_valid and StateNormalizer.fingerprint(loaded.state) == original)
	for run: RunState in [state, loaded.state]:
		assert(F.play(run, registry, &"tile.development.grand_market", Vector2i.UP) > 0)
		var played: bool = false
		for copy_id: int in run.expansion.hand.duplicate():
			var legal: Array[PlacementOption] = F.options(run, registry, copy_id)
			if not legal.is_empty():
				assert(RulesEngine.execute(run, registry, F.command(legal[0])).is_valid)
				played = true
				break
		assert(played)
	assert(StateNormalizer.fingerprint(state) == StateNormalizer.fingerprint(loaded.state))
	print("DEMO seed=16; normal placements=%d; Tracks=%s; completed-host Housing, full-network Market, physical Grand Market replacement; identical save/load continuation and future draw." % [state.expansion.normal_placements, str(state.features.tracks.values)])
	var failures: Array = []
	for script: GDScript in [Scenarios, Acceptance]:
		var suite: RefCounted = script.new()
		for test: Callable in suite.tests():
			if test.call() != true:
				suite.failures.append("Scenario did not finish: " + String(test.get_method()))
		failures.append_array(suite.failures)
	for failure: String in failures:
		printerr("FAIL: " + failure)
	if failures.is_empty():
		print("DEMO RESULT: immediate isolation, shared Development batches, Port River intents, Monastery/Abbey stages, host mergers, Forest preservation, physical zones, inert loading and deterministic continuation passed.")
	_finished = true
	quit(0 if failures.is_empty() else 1)


func _check_finished() -> void:
	if not _finished:
		printerr("FAIL: Phase-5 demonstration did not reach completion")
		quit(1)
