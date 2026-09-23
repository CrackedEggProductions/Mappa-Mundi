extends "res://tests/framework/test_suite.gd"

const Fixture = preload("res://tests/fixtures/phase_five_factory.gd")
const TYPE = DomainTypes.FeatureType
const PREFIX: String = "tile.development."


func tests() -> Array[Callable]:
	var result: Array[Callable] = [second_slot_rejected_atomically, stale_preview_rejected,
		forged_host_rejected, unlocked_context_required, upgrades_require_exact_base,
		upgrade_target_is_part_of_intent, meaningless_rotation_rejected,
		field_and_forest_require_actual_geography, port_requires_explicit_contact]
	for stage: String in ["housing", "mill", "monastery", "foresters_lodge", "market", "port", "town_square", "abbey", "grand_market"]:
		result.append(query_is_deterministic.bind(stage))
	return result


func query_is_deterministic(stage: String) -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 3)
	Fixture.complete_settlement(state, registry)
	Fixture.ports(state, registry)
	if stage == "abbey":
		Fixture.play(state, registry, &"tile.development.monastery", Vector2i.UP)
	elif stage == "grand_market":
		Fixture.play(state, registry, &"tile.development.market", Vector2i.UP)
	var copy_id: int = Fixture.acquire_hand(state, StringName(PREFIX + stage))
	var before: String = StateNormalizer.fingerprint(state)
	var options: Array[PlacementOption] = Fixture.options(state, registry, copy_id)
	expect_true(not options.is_empty(), "%s has a legal controlled target" % stage)
	var repeated: Array[PlacementOption] = Fixture.options(state, registry, copy_id)
	var signatures: Array[String] = []
	var coordinates: Array[Vector2i] = state.expansion.board.sorted_coordinates()
	var last_coordinate_index: int = -1
	for index: int in range(options.size()):
		var option: PlacementOption = options[index]
		expect_equal(option.rotation, 0, "%s has no duplicate rotations" % stage)
		expect_equal(option.signature, repeated[index].signature, "%s stable intent" % stage)
		expect_true(not signatures.has(option.signature), "%s intent unique" % stage)
		expect_true(coordinates.find(option.coordinate) >= last_coordinate_index, "Canonical coordinate order")
		last_coordinate_index = coordinates.find(option.coordinate)
		signatures.append(option.signature)
		expect_true(RulesEngine.validate(state, registry, Fixture.command(option)).is_valid, "Every query result revalidates")
	expect_equal(StateNormalizer.fingerprint(state), before, "Queries and validation allocate nothing")
	return true


func second_slot_rejected_atomically() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	var first: int = Fixture.play(state, registry, &"tile.development.housing", Vector2i.ZERO)
	var second: int = Fixture.acquire_hand(state, &"tile.development.housing")
	expect_true(state.expansion.board.get_cell(Vector2i.ZERO).developments is Array, "Future-compatible overlays use an Array")
	expect_equal(Fixture.development(state, Vector2i.ZERO).tile_copy_id, first, "First physical copy occupies slot")
	expect_true(Fixture.options(state, registry, second).is_empty(), "Occupied normal slot excluded")
	var intent: PlaceTileCommand = PlaceTileCommand.new(second, TileLocationState.Kind.ACTIVE_HAND, Vector2i.ZERO)
	intent.placement_mode = DomainTypes.PlacementMode.DEVELOPMENT
	intent.host_lineage_id = Fixture.development(state, Vector2i.ZERO).host_lineage_id
	_rejected_unchanged(state, registry, intent)
	return true


func stale_preview_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	var copy_id: int = Fixture.acquire_hand(state, &"tile.development.housing")
	var intent: PlaceTileCommand = Fixture.command(Fixture.options(state, registry, copy_id)[0])
	state.expansion.state_revision += 1
	_rejected_unchanged(state, registry, intent)
	return true


func forged_host_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	var copy_id: int = Fixture.acquire_hand(state, &"tile.development.housing")
	var intent: PlaceTileCommand = Fixture.command(Fixture.options(state, registry, copy_id)[0])
	intent.host_lineage_id = state.features.component_at(Vector2i.ZERO, TYPE.FOREST).lineage_id
	intent.expected_signature = ""
	_rejected_unchanged(state, registry, intent)
	return true


func unlocked_context_required() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	for id: StringName in [&"tile.development.market", &"tile.development.port", &"tile.development.town_square", &"tile.development.abbey", &"tile.development.grand_market"]:
		var copy_id: int = Fixture.acquire_hand(state, id)
		expect_true(Fixture.options(state, registry, copy_id).is_empty(), "Act-I cannot play locked content")
	return true


func upgrades_require_exact_base() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 3)
	for id: StringName in [&"tile.development.abbey", &"tile.development.grand_market"]:
		expect_true(Fixture.options(state, registry, Fixture.acquire_hand(state, id)).is_empty(), "Upgrade cannot use an empty slot")
	Fixture.play(state, registry, &"tile.development.housing", Vector2i.ZERO)
	for id: StringName in [&"tile.development.abbey", &"tile.development.grand_market"]:
		expect_true(Fixture.options(state, registry, Fixture.acquire_hand(state, id)).is_empty(), "Upgrade cannot replace Housing")
	return true


func upgrade_target_is_part_of_intent() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 3)
	var base: int = Fixture.play(state, registry, &"tile.development.market", Vector2i.ZERO)
	var copy_id: int = Fixture.acquire_hand(state, &"tile.development.grand_market")
	var option: PlacementOption = Fixture.options(state, registry, copy_id)[0]
	expect_equal(option.target_development_copy_id, base, "Upgrade intent identifies physical prerequisite")
	var intent: PlaceTileCommand = Fixture.command(option)
	intent.target_development_copy_id = copy_id
	intent.expected_signature = ""
	_rejected_unchanged(state, registry, intent)
	return true


func meaningless_rotation_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	var copy_id: int = Fixture.acquire_hand(state, &"tile.development.housing")
	var intent: PlaceTileCommand = Fixture.command(Fixture.options(state, registry, copy_id)[0])
	intent.rotation = 1
	_rejected_unchanged(state, registry, intent)
	return true


func field_and_forest_require_actual_geography() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	Fixture.complete_settlement(state, registry)
	for stage: String in ["mill", "monastery"]:
		var options: Array[PlacementOption] = Fixture.options(state, registry, Fixture.acquire_hand(state, StringName(PREFIX + stage)))
		expect_equal(options.size(), 1, "Only actual Field-containing hamlet qualifies")
		expect_equal(options[0].coordinate, Vector2i.UP, "Founding has no Field despite natural artwork")
	var lodge_options: Array[PlacementOption] = Fixture.options(state, registry, Fixture.acquire_hand(state, &"tile.development.foresters_lodge"))
	expect_equal(lodge_options.size(), 1, "Only Forest-containing founding qualifies")
	expect_equal(lodge_options[0].coordinate, Vector2i.ZERO, "Field alone is not Forest")
	return true


func port_requires_explicit_contact() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 2)
	var copy_id: int = Fixture.acquire_hand(state, &"tile.development.port")
	expect_true(Fixture.options(state, registry, copy_id).is_empty(), "Coexisting River and Settlement does not invent explicit contact")
	Fixture.ports(state, registry, 1)
	var options: Array[PlacementOption] = Fixture.options(state, registry, copy_id)
	expect_true(not options.is_empty(), "Riverside Hamlet explicitly permits Port")
	var river: int = state.features.component_at(Vector2i.DOWN, TYPE.RIVER).lineage_id
	for option: PlacementOption in options:
		expect_equal(option.river_lineage_id, river, "Each Port intent names its connected River")
	return true


func _rejected_unchanged(state: RunState, registry: ContentRegistry, intent: PlaceTileCommand) -> void:
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, registry, intent).is_valid, "Invalid intent returns structured failure")
	expect_equal(StateNormalizer.fingerprint(state), before, "Invalid intent changes no zones, scores, history, RNG or IDs")
