class_name CharterContentValidator
extends RefCounted
## Exact nine alpha evaluators, tunable canonical targets, and ordered rewards.

const ROSTER: Dictionary = {
	&"charter.a1_growing_realm": {"population": 20, "settlement_completions": 2, "exceed_population": 30},
	&"charter.a1_open_roads": {"trade": 20, "road_completions": 2, "network_settlements": 2, "exceed_trade": 30},
	&"charter.a1_living_landscape": {"ecology": 20, "forest_completions": 1, "river_completions": 1, "exceed_ecology": 30},
	&"charter.a2_market_towns": {"trade": 40, "market_settlements": 2, "network_settlements": 3, "exceed_trade": 55},
	&"charter.a2_growing_communities": {"population": 40, "settlement_size": 6, "developments": 2, "exceed_population": 55},
	&"charter.a2_stewardship_of_land": {"ecology": 40, "forest_size": 6, "river_size": 6, "exceed_ecology": 55},
	&"charter.grand_great_metropolis": {"population": 70, "settlement_size": 8, "development_families": 3, "other_settlements": 2, "exceed_population": 90, "exceed_settlement_size": 10},
	&"charter.grand_merchant_republic": {"trade": 70, "network_settlements": 4, "commercial_settlements": 2, "exceed_trade": 90, "exceed_network_settlements": 5},
	&"charter.grand_living_heritage": {"ecology": 60, "culture": 40, "forest_size": 8, "river_size": 8, "enclosure_completions": 1, "exceed_ecology": 80, "exceed_culture": 60},
}
const FORECASTS: Dictionary = {
	&"charter.grand_great_metropolis": "The realm will ultimately be judged by the greatness and sophistication of its settlements.",
	&"charter.grand_merchant_republic": "The realm will ultimately be judged by the reach and prosperity of its trade network.",
	&"charter.grand_living_heritage": "The realm will ultimately be judged by its stewardship of nature and cultural legacy.",
}


static func act_for(id: StringName) -> int:
	if id not in ROSTER:
		return 0
	return 1 if String(id).begins_with("charter.a1_") else (2 if String(id).begins_with("charter.a2_") else 3)


static func validate(definitions: Array[CharterDefinition]) -> ValidationResult:
	if definitions.size() != ROSTER.size():
		return ValidationResult.failure(&"invalid_charter_roster", "Alpha requires exactly nine Charters.")
	var seen: Array[StringName] = []
	for definition: CharterDefinition in definitions:
		if definition == null or definition.definition_id not in ROSTER:
			return ValidationResult.failure(&"invalid_charter_roster", "Missing or deferred Charter in alpha pool.")
		if definition.definition_id in seen:
			return ValidationResult.failure(&"duplicate_definition_id", "Charter IDs must be unique.")
		seen.append(definition.definition_id)
		var act: int = act_for(definition.definition_id)
		var fulfill: Array[StringName] = []
		var exceed: Array[StringName] = []
		if act == 1:
			fulfill.append(&"tile_reward")
			exceed.append(&"relic_offer")
		elif act == 2:
			fulfill.assign([&"relic_offer", &"tile_reward"])
			exceed.append(&"major_reward")
		if definition.display_name.strip_edges().is_empty() or definition.evaluation_act != act \
				or definition.behavior_id != StringName(String(definition.definition_id).trim_prefix("charter.")) \
				or definition.targets != ROSTER[definition.definition_id] \
				or definition.fulfill_rewards != fulfill or definition.exceed_rewards != exceed \
				or definition.forecast_text != FORECASTS.get(definition.definition_id, ""):
			return ValidationResult.failure(&"invalid_charter_configuration", "Charter metadata differs from the canonical alpha.")
	return ValidationResult.success()
