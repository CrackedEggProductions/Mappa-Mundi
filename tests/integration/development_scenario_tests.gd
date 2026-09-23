extends "res://tests/framework/test_suite.gd"

const Fixture = preload("res://tests/fixtures/phase_five_factory.gd")
const TYPE = DomainTypes.FeatureType
const TRACK = DomainTypes.TrackType


func tests() -> Array[Callable]:
	return [housing_unfinished_then_completion, housing_immediate_isolation,
		housing_reopened_history_is_not_current_completion, duplicate_housing_recompletion,
		market_full_network_and_upgrade_isolation, port_immediate_isolation,
		lodge_preserves_forest_bonus, ordinary_development_cancels_future_preservation,
		town_square_uses_host_families, mill_immediate_and_recompletion,
		monastery_immediate_completion, monastery_later_eighth_square,
		abbey_completed_upgrade, abbey_incomplete_upgrade,
		development_reserve_consumes_no_refill, upgrade_reserve_consumes_no_refill,
		survey_development, survey_upgrade, playable_development_prevents_cycle,
		playable_upgrade_prevents_cycle, dead_developments_cycle,
		bag_development_prevents_global_stalemate, bag_upgrade_prevents_global_stalemate,
		development_save_continuation]


func housing_unfinished_then_completion() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	var before: int = state.features.tracks.values[TRACK.POPULATION]
	var geometry_revision: int = state.expansion.board.revision
	var placements: int = state.expansion.normal_placements
	var copy_id: int = Fixture.play(state, registry, &"tile.development.housing", Vector2i.ZERO)
	expect_equal(state.features.tracks.values[TRACK.POPULATION], before, "Unfinished host has no immediate effect")
	expect_equal(state.expansion.board.revision, geometry_revision, "Overlay preserves base geometry revision")
	expect_equal(state.expansion.normal_placements, placements + 1, "Development is one normal placement")
	expect_equal(Fixture.location(state, copy_id), TileLocationState.Kind.BOARD_DEVELOPMENT, "Hand copy is now physical overlay")
	expect_true(not state.expansion.hand.has(0), "Hand refills after consequences")
	Fixture.play(state, registry, &"tile.hamlet_edge", Vector2i.UP)
	expect_equal(_events(state, &"development_completion_trigger", copy_id), 1, "Later actual command completes host and triggers Housing")
	expect_equal(_gains(state, copy_id, TRACK.POPULATION), 2, "Exactly one Housing effect")
	return true


func housing_immediate_isolation() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	Fixture.complete_settlement(state, registry)
	var first: int = Fixture.play(state, registry, &"tile.development.housing", Vector2i.ZERO)
	var before: int = state.features.tracks.values[TRACK.POPULATION]
	var completions: int = state.features.completions.size()
	var events: int = _events(state, &"feature_completed")
	var second: int = Fixture.play(state, registry, &"tile.development.housing", Vector2i.UP)
	expect_equal(state.features.tracks.values[TRACK.POPULATION] - before, 2, "Only newly placed Housing resolves")
	expect_equal(_events(state, &"development_immediate_effect", first), 1, "Existing Housing never retriggers from peer placement")
	expect_equal(_events(state, &"development_immediate_effect", second), 1, "New Housing resolves once")
	expect_equal(state.features.completions.size(), completions, "Immediate effect does not invent completion record")
	expect_equal(_events(state, &"feature_completed"), events, "Immediate effect does not invent feature_completed event")
	return true


func housing_reopened_history_is_not_current_completion() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	Fixture.complete_settlement(state, registry)
	assert(Fixture.Previous.Previous.rewrite(state, registry, Vector2i.UP, [4, 0, 4, 0]).is_valid)
	var host: FeatureLineageState = Fixture.Previous.Previous.lineage_at(state, Vector2i.ZERO, TYPE.SETTLEMENT)
	expect_true(not host.completed and not host.completion_ids.is_empty(), "Established historical host is currently reopened")
	var before: int = state.features.tracks.values[TRACK.POPULATION]
	var copy_id: int = Fixture.play(state, registry, &"tile.development.housing", Vector2i.UP)
	expect_equal(state.features.tracks.values[TRACK.POPULATION], before, "Historical Establishment does not satisfy immediate condition")
	Fixture.play(state, registry, &"tile.hamlet_edge", Vector2i(0, -2))
	expect_equal(_gains(state, copy_id, TRACK.POPULATION), 2, "Later genuine re-completion triggers Housing")
	return true


func duplicate_housing_recompletion() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	Fixture.complete_settlement(state, registry)
	var first: int = Fixture.play(state, registry, &"tile.development.housing", Vector2i.ZERO)
	var second: int = Fixture.play(state, registry, &"tile.development.housing", Vector2i.UP)
	assert(Fixture.Previous.Previous.rewrite(state, registry, Vector2i.UP, [4, 0, 4, 0]).is_valid)
	Fixture.play(state, registry, &"tile.hamlet_edge", Vector2i(0, -2))
	for copy_id: int in [first, second]:
		expect_equal(_events(state, &"development_completion_trigger", copy_id), 1, "Each physical copy retriggers independently")
		expect_equal(_gains(state, copy_id, TRACK.POPULATION), 4, "Immediate plus genuine re-completion effects remain separate from base histories")
	return true


func market_full_network_and_upgrade_isolation() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 3)
	Fixture.complete_settlement(state, registry)
	Fixture.Previous.Previous.add(state, registry, &"tile.settlement_gate", Vector2i.RIGHT, 2)
	Fixture.Previous.Previous.add(state, registry, &"tile.settlement_gate", Vector2i.ONE)
	Fixture.Previous.Previous.add(state, registry, &"tile.settlement_gate", Vector2i(2, 1), 2)
	var market: int = Fixture.play(state, registry, &"tile.development.market", Vector2i.ZERO)
	expect_equal(_gains(state, market, TRACK.TRADE), 2, "Market counts two OTHER Settlements across full transitive network")
	var housing: int = Fixture.play(state, registry, &"tile.development.housing", Vector2i.UP)
	var completions: int = state.features.completions.size()
	var grand: int = Fixture.play(state, registry, &"tile.development.grand_market", Vector2i.ZERO)
	expect_equal(_gains(state, grand, TRACK.TRADE), 4, "Grand Market scores double current full-network reach")
	expect_equal(_gains(state, market, TRACK.TRADE), 2, "Old earnings remain unchanged")
	expect_equal(_gains(state, housing, TRACK.POPULATION), 2, "Upgrade does not trigger peer Housing")
	expect_equal(state.features.completions.size(), completions, "Upgrade does not invent Settlement completion")
	_replacement(state, market, grand, Vector2i.ZERO, &"family.market")
	assert(Fixture.Previous.Previous.rewrite(state, registry, Vector2i.UP, [4, 0, 4, 0]).is_valid)
	Fixture.play(state, registry, &"tile.hamlet_edge", Vector2i(0, -2))
	expect_equal(_gains(state, grand, TRACK.TRADE), 8, "Grand Market retriggers on genuine completion")
	expect_equal(_gains(state, market, TRACK.TRADE), 2, "Removed Market never retriggers")
	return true


func port_immediate_isolation() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 2)
	Fixture.ports(state, registry)
	var first: int = Fixture.play(state, registry, &"tile.development.port", Vector2i.DOWN)
	var second: int = Fixture.play(state, registry, &"tile.development.port", Vector2i(0, 2))
	expect_equal(_gains(state, first, TRACK.TRADE), 2, "Old Port gets its original base Trade only")
	expect_equal(_gains(state, second, TRACK.TRADE), 3, "New Port counts other Port on specific connected River")
	expect_equal(Fixture.development(state, Vector2i.DOWN).river_lineage_id,
		Fixture.development(state, Vector2i(0, 2)).river_lineage_id, "Both preserve their selected connected River")
	return true


func lodge_preserves_forest_bonus() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	var lodge: int = Fixture.play(state, registry, &"tile.development.foresters_lodge", Vector2i.ZERO)
	expect_equal(_gains(state, lodge, TRACK.ECOLOGY), 0, "Unfinished Forest has no immediate Lodge score")
	Fixture.play(state, registry, &"tile.forest_edge", Vector2i.LEFT)
	expect_equal(state.features.tracks.values[TRACK.ECOLOGY], 5, "Two Forest components plus preservation plus Lodge")
	var second: int = Fixture.play(state, registry, &"tile.development.foresters_lodge", Vector2i.LEFT)
	expect_equal(_gains(state, second, TRACK.ECOLOGY), 1, "New Lodge on complete Forest scores immediately")
	assert(Fixture.Previous.Previous.rewrite(state, registry, Vector2i.LEFT, [0, 1, 0, 1]).is_valid)
	Fixture.play(state, registry, &"tile.forest_edge", Vector2i(-2, 0))
	expect_equal(state.features.completions[-1].gains[TRACK.ECOLOGY], 3, "One new component plus preservation despite duplicate Lodges")
	expect_equal(_gains(state, lodge, TRACK.ECOLOGY), 2, "First Lodge retriggers")
	expect_equal(_gains(state, second, TRACK.ECOLOGY), 2, "Second Lodge independently retriggers")
	return true


func ordinary_development_cancels_future_preservation() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	Fixture.Previous.Previous.add(state, registry, &"tile.forest_edge", Vector2i.LEFT, 1)
	expect_equal(state.features.tracks.values[TRACK.ECOLOGY], 4, "Original Forest preservation scored")
	Fixture.play(state, registry, &"tile.development.monastery", Vector2i.LEFT)
	expect_equal(state.features.tracks.values[TRACK.ECOLOGY], 4, "New ordinary Development never removes earned preservation")
	assert(Fixture.Previous.Previous.rewrite(state, registry, Vector2i.LEFT, [0, 1, 0, 1]).is_valid)
	Fixture.play(state, registry, &"tile.forest_edge", Vector2i(-2, 0))
	expect_equal(state.features.tracks.values[TRACK.ECOLOGY], 5, "Later genuine completion scores new component without preservation")
	expect_true(not state.features.completions[-1].forest_undeveloped, "Completion captures current developed status")
	return true


func town_square_uses_host_families() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 2)
	Fixture.complete_settlement(state, registry)
	Fixture.play(state, registry, &"tile.development.mill", Vector2i.UP)
	var square: int = Fixture.play(state, registry, &"tile.development.town_square", Vector2i.ZERO)
	expect_equal(_gains(state, square, TRACK.CULTURE), 2, "Tile-based Mill sharing Settlement square is not a hosted family")
	expect_equal(DevelopmentService.families(state, Fixture.development(state, Vector2i.ZERO).host_lineage_id), [&"family.town_square"], "Square includes itself and excludes unrelated host systems")
	return true


func mill_immediate_and_recompletion() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	Fixture.complete_settlement(state, registry)
	var mill: int = Fixture.play(state, registry, &"tile.development.mill", Vector2i.UP)
	expect_equal(_gains(state, mill, TRACK.POPULATION), 2, "Explicit same-tile Field/Settlement contact resolves immediately")
	expect_equal(_gains(state, mill, TRACK.TRADE), 1, "Orthogonally touching Founding River gives Trade")
	expect_equal(Fixture.development(state, Vector2i.UP).host_lineage_id, 0, "Mill remains tile-based")
	assert(Fixture.Previous.Previous.rewrite(state, registry, Vector2i.UP, [4, 0, 4, 0]).is_valid)
	Fixture.play(state, registry, &"tile.hamlet_edge", Vector2i(0, -2))
	expect_equal(_gains(state, mill, TRACK.POPULATION), 4, "Mill reevaluates touching Settlement on re-completion")
	return true


func monastery_immediate_completion() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	var center: Vector2i = Fixture.fields(state, registry, 8)
	var copy_id: int = Fixture.play(state, registry, &"tile.development.monastery", center)
	var enclosure: EnclosureState = state.features.enclosures[0]
	expect_equal(enclosure.development_tile_copy_id, copy_id, "Live enclosure names its physical overlay")
	expect_equal(enclosure.coordinate, center, "Enclosure is centered on host tile")
	expect_equal(enclosure.completed_stages, [&"monastery"], "Already occupied eight squares complete stage immediately")
	expect_equal(state.features.tracks.values[TRACK.CULTURE], 13, "Monastery gets five plus eight natural squares")
	Fixture.play(state, registry, &"tile.open_fields", Vector2i(2, 3))
	expect_equal(state.features.tracks.values[TRACK.CULTURE], 13, "Later placements do not rescore stage")
	return true


func monastery_later_eighth_square() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	var center: Vector2i = Fixture.fields(state, registry, 7)
	Fixture.play(state, registry, &"tile.development.monastery", center)
	expect_true(state.features.enclosures[0].completed_stages.is_empty(), "Seven neighbors keep stage unfinished")
	expect_equal(state.features.tracks.values[TRACK.CULTURE], 0, "No early score")
	Fixture.play(state, registry, &"tile.open_fields", center + Vector2i(-1, -1))
	expect_equal(state.features.enclosures[0].completed_stages, [&"monastery"], "Eighth neighbor completes via normal Expansion command")
	expect_equal(state.features.tracks.values[TRACK.CULTURE], 13, "Later live completion scores once")
	return true


func abbey_completed_upgrade() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 2)
	var center: Vector2i = Fixture.fields(state, registry, 8)
	var monastery: int = Fixture.play(state, registry, &"tile.development.monastery", center)
	var enclosure_id: int = state.features.enclosures[0].enclosure_id
	var abbey: int = Fixture.play(state, registry, &"tile.development.abbey", center)
	_replacement(state, monastery, abbey, center, &"family.monastery")
	expect_equal(state.features.enclosures[0].enclosure_id, enclosure_id, "Upgrade preserves enclosure identity")
	expect_equal(state.features.enclosures[0].completed_stages, [&"monastery", &"abbey"], "Old Monastery history survives new Abbey stage")
	expect_equal(state.features.tracks.values[TRACK.CULTURE], 29, "Monastery thirteen plus Abbey sixteen; old stage never rescored")
	expect_equal(state.features.enclosures[0].development_tile_copy_id, abbey, "Enclosure follows upgraded physical copy")
	return true


func abbey_incomplete_upgrade() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 2)
	var center: Vector2i = Fixture.fields(state, registry, 7)
	var monastery: int = Fixture.play(state, registry, &"tile.development.monastery", center)
	var abbey: int = Fixture.play(state, registry, &"tile.development.abbey", center)
	_replacement(state, monastery, abbey, center, &"family.monastery")
	expect_equal(state.features.tracks.values[TRACK.CULTURE], 0, "Incomplete upgraded enclosure has no immediate score")
	Fixture.play(state, registry, &"tile.open_fields", center + Vector2i(-1, -1))
	expect_equal(state.features.tracks.values[TRACK.CULTURE], 16, "Only Abbey stage resolves when eighth neighbor arrives")
	expect_equal(state.features.enclosures[0].completed_stages, [&"abbey"], "Never-completed Monastery does not acquire false completion history")
	return true


func development_reserve_consumes_no_refill() -> bool:
	return _reserve_scenario(false)


func upgrade_reserve_consumes_no_refill() -> bool:
	return _reserve_scenario(true)


func _reserve_scenario(upgrade: bool) -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 3)
	if upgrade:
		Fixture.play(state, registry, &"tile.development.market", Vector2i.ZERO)
	var copy_id: int = Fixture.acquire_hand(state, &"tile.development.grand_market" if upgrade else &"tile.development.housing")
	expect_true(RulesEngine.execute(state, registry, ReserveTileCommand.new(copy_id)).is_valid, "Physical copy moves from hand to Reserve")
	var hand: Array[int] = state.expansion.hand.duplicate()
	var bag: Array[int] = state.expansion.bag.duplicate()
	var before: int = state.expansion.normal_placements
	var intent: PlaceTileCommand = Fixture.command(Fixture.options(state, registry, copy_id)[0], TileLocationState.Kind.RESERVE)
	expect_true(RulesEngine.execute(state, registry, intent).is_valid, "Reserve Development/Upgrade commits normally")
	expect_equal(state.expansion.reserve_id, 0, "Reserve empties")
	expect_equal(state.expansion.hand, hand, "Reserve placement never refills active hand")
	expect_equal(state.expansion.bag, bag, "Reserve placement performs no draw")
	expect_equal(state.expansion.normal_placements, before + 1, "Reserve overlay consumes one normal placement")
	return true


func survey_development() -> bool:
	return _survey_scenario(&"tile.development.housing")


func survey_upgrade() -> bool:
	return _survey_scenario(&"tile.development.abbey")


func _survey_scenario(id: StringName) -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 2)
	var copy_id: int = Fixture.acquire_hand(state, id)
	var before: int = state.expansion.normal_placements
	expect_true(RulesEngine.execute(state, registry, SurveyTileCommand.new(copy_id)).is_valid, "Survey accepts physical Development/Upgrade")
	expect_equal(Fixture.location(state, copy_id), TileLocationState.Kind.REMOVED_FROM_RUN, "Surveyed copy is permanently removed")
	expect_true(state.expansion.removed_ids.has(copy_id), "Survey removal is recorded")
	expect_true(not state.expansion.hand.has(copy_id), "Survey refills vacated slot")
	expect_equal(state.expansion.normal_placements, before, "Survey is not a normal placement")
	return true


func playable_development_prevents_cycle() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _dead_state(registry)
	Fixture.acquire_hand(state, &"tile.development.housing")
	expect_true(not StalemateRules.is_dead_hand(state, registry), "Playable Housing prevents free cycle with no Expansion copies")
	var before: String = StateNormalizer.fingerprint(state)
	expect_equal(RulesEngine.execute(state, registry, CycleDeadHandCommand.new()).error_code, &"hand_is_playable", "Free cycle rejected")
	expect_equal(StateNormalizer.fingerprint(state), before, "Rejected cycle preserves state")
	return true


func playable_upgrade_prevents_cycle() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _dead_state(registry)
	Fixture.play(state, registry, &"tile.development.market", Vector2i.ZERO)
	for slot: int in range(3):
		Fixture.acquire_hand(state, &"tile.development.abbey", slot)
	Fixture.acquire_hand(state, &"tile.development.grand_market")
	expect_true(not StalemateRules.is_dead_hand(state, registry), "Valid physical Upgrade target prevents free cycle")
	return true


func dead_developments_cycle() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _dead_state(registry)
	expect_true(StalemateRules.is_dead_hand(state, registry), "Three untargetable Upgrades are dead")
	expect_true(StalemateRules.is_global_stalemate(state, registry), "Bag-wide query also sees no target")
	var count: int = state.tile_copies.size()
	expect_true(RulesEngine.execute(state, registry, CycleDeadHandCommand.new()).is_valid, "Dead hand cycles")
	expect_equal(state.tile_copies.size(), count + 3, "Exactly existing three emergency Expansions added")
	for tile: TileCopyState in state.tile_copies:
		if tile.acquisition_source == &"emergency_replenishment":
			expect_true(registry.get_config().emergency_definitions.has(tile.definition_id), "Emergency composition unchanged")
	return true


func bag_development_prevents_global_stalemate() -> bool:
	return _bag_playable(&"tile.development.housing", false)


func bag_upgrade_prevents_global_stalemate() -> bool:
	return _bag_playable(&"tile.development.grand_market", true)


func _bag_playable(id: StringName, upgrade: bool) -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 3)
	if upgrade:
		Fixture.play(state, registry, &"tile.development.market", Vector2i.ZERO)
	_make_dead(state)
	state.expansion.bag.append(PhysicalTileRules.acquire(state, id, &"scenario_fixture", TileLocationState.Kind.BAG))
	expect_true(StalemateRules.is_dead_hand(state, registry), "Hand is dead")
	expect_true(not StalemateRules.is_global_stalemate(state, registry), "Playable physical bag overlay prevents global stalemate")
	return true


func development_save_continuation() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 3)
	Fixture.complete_settlement(state, registry)
	Fixture.play(state, registry, &"tile.development.housing", Vector2i.ZERO)
	var saved: SerializationResult = RunSerializer.serialize(state, registry)
	expect_true(saved.validation.is_valid, "Development state saves")
	var restored: DeserializationResult = RunSerializer.deserialize(saved.json_text, registry)
	expect_true(restored.validation.is_valid, "Development state loads")
	if restored.state == null:
		return true
	for run: RunState in [state, restored.state]:
		Fixture.play(run, registry, &"tile.development.market", Vector2i.UP)
		Fixture.play(run, registry, &"tile.development.grand_market", Vector2i.UP)
	expect_equal(StateNormalizer.fingerprint(state), StateNormalizer.fingerprint(restored.state), "Commands, effects, future draws, IDs and RNG continue identically")
	return true


func _dead_state(registry: ContentRegistry) -> RunState:
	var state: RunState = Fixture.create(registry, 3)
	_make_dead(state)
	return state


func _make_dead(state: RunState) -> void:
	for copy_id: int in state.expansion.bag:
		state.expansion.removed_ids.append(copy_id)
		PhysicalTileRules.set_location(state, copy_id, TileLocationState.Kind.REMOVED_FROM_RUN)
	state.expansion.bag.clear()
	for slot: int in range(3):
		Fixture.acquire_hand(state, &"tile.development.abbey", slot)


func _events(state: RunState, kind: StringName, copy_id: int = 0) -> int:
	var count: int = 0
	for event: FeatureHistoryRecord in state.features.history:
		if event.kind == kind and (copy_id == 0 or event.source_id == copy_id):
			count += 1
	return count


func _gains(state: RunState, copy_id: int, track: int) -> int:
	var total: int = 0
	for event: FeatureHistoryRecord in state.features.history:
		if event.kind == &"realm_track_changed" and event.source_id == copy_id and event.track == track:
			total += event.amount
	return total


func _replacement(state: RunState, old: int, upgraded: int, at: Vector2i, family: StringName) -> void:
	expect_equal(Fixture.location(state, old), TileLocationState.Kind.REMOVED_FROM_RUN, "Prerequisite is permanently removed")
	expect_true(state.expansion.removed_ids.has(old), "Removed prerequisite recorded")
	expect_true(not state.expansion.hand.has(old) and not state.expansion.bag.has(old) and state.expansion.reserve_id != old, "Old copy never returns to an active zone")
	expect_equal(Fixture.development(state, at).tile_copy_id, upgraded, "Upgrade occupies original slot")
	expect_equal(Fixture.development(state, at).family_id, family, "Family identity survives upgrade")
	expect_equal(Fixture.development(state, at).replaced_copy_id, old, "Physical replacement is auditable")
