extends "res://tests/framework/test_suite.gd"

const F = preload("res://tests/fixtures/phase_eight_factory.gd")
const Six = preload("res://tests/fixtures/phase_six_factory.gd")
const TYPE = DomainTypes.FeatureType


func tests() -> Array[Callable]:
	return [long_road_bridge_pays_suppressed_growth, city_housing_mill_steward_not_doubled]


func long_road_bridge_pays_suppressed_growth() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = Six.river(registry)
	F.Geography.add(state, registry, &"tile.bending_road", Vector2i.RIGHT, 2)
	F.Geography.add(state, registry, &"tile.road_end", Vector2i.ONE)
	expect_equal(state.features.largest_completed_sizes[TYPE.ROAD], 3, "Record established before acquiring Long Road")
	F.activate(state)
	F.equip(state, registry, RelicRules.LONG_ROAD)
	F.Geography.add(state, registry, &"tile.road_end", Vector2i(-1, 1), 2)
	F.Geography.add(state, registry, &"tile.road_end", Vector2i(-1, 2))
	var suppressed_id: int = F.Previous.member(state, Vector2i(-1, 1), TYPE.ROAD)
	var suppressed: FeatureLineageState = state.features.lineage(suppressed_id)
	expect_true(suppressed.completed, "Two-tile Road genuinely completed")
	expect_true(suppressed.scored_component_ids.is_empty(), "Smaller Road was suppressed without marking growth paid")
	expect_equal(state.features.completions[-1].gains[1], 0, "Suppressed base Trade is zero")
	var before: int = state.features.tracks.values[1]
	F.play(state, registry, Six.BRIDGE, Vector2i.DOWN, -1, &"bridge")
	F.decline_assignment(state, registry)
	var merged: FeatureLineageState = state.features.lineage(F.Previous.member(state, Vector2i.DOWN, TYPE.ROAD))
	var record: FeatureCompletionRecord = state.features.completions[-1]
	expect_true(merged.completed and suppressed_id in merged.parent_ids, "Bridge genuinely recompletes merged Road")
	expect_equal(record.total_size, 6, "Full physical merged size sets record")
	expect_equal(record.new_component_ids.size(), 3, "Only two unpaid old tiles and one new Bridge component qualify")
	expect_equal(record.gains[1], 6, "Qualifying new base Road payout doubled")
	expect_equal(state.features.tracks.values[1] - before, 6, "No duplicate payment for original paid three-tile Road")
	expect_equal(state.features.largest_completed_sizes[TYPE.ROAD], 6, "Historical record updates after comparison")
	var loaded: RunState = F.load_copy(state, registry)
	expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "Suppression, bridge genealogy, paid history and record save exactly")
	return true


func city_housing_mill_steward_not_doubled() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry)
	F.equip(state, registry, RelicRules.CITY)
	F.equip(state, registry, RelicRules.GREEN)
	F.play(state, registry, &"tile.development.housing", Vector2i.ZERO)
	F.Previous.assign(state, registry, TYPE.SETTLEMENT)
	F.play(state, registry, &"tile.road_end", Vector2i.RIGHT, 3)
	F.decline_assignment(state, registry)
	F.play(state, registry, &"tile.open_fields", Vector2i(1, -1))
	F.decline_assignment(state, registry)
	F.play(state, registry, &"tile.development.mill", Vector2i(1, -1))
	F.decline_assignment(state, registry)
	var before: int = state.features.tracks.values[0]
	var culture_before: int = state.features.tracks.values[2]
	F.play(state, registry, &"tile.hamlet_edge", Vector2i.UP, 2)
	F.decline_assignment(state, registry)
	var record: FeatureCompletionRecord = state.features.completions[-1]
	var raw_base: int = 2 * record.new_component_ids.size() + record.new_field_ids.size() + record.new_river_ids.size()
	expect_equal(record.base_multiplier, 2, "Largest Settlement qualifies")
	expect_equal(record.gains[0], 2 * raw_base, "Only newly scoring base is doubled")
	expect_equal(state.features.tracks.values[0] - before, 2 * raw_base + 6, "Housing +2, Mill +2 and generic Steward +2 remain undoubled")
	expect_equal(state.features.tracks.values[2] - culture_before, 2, "Village Green remains full size +2, not doubled")
	expect_equal(state.specialists.pieces[0].status, SpecialistPieceState.Status.AVAILABLE, "Generic Steward returned normally")
	var loaded: RunState = F.load_copy(state, registry)
	expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "Base modifiers and independent completion effects round-trip")
	return true
