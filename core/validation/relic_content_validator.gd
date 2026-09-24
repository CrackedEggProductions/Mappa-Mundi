class_name RelicContentValidator
extends RefCounted
## Reduced alpha roster: prototype Relics cannot enter offers or saves.

const ROSTER: Dictionary = {
	&"relic.boundary_stones": 1, &"relic.surveyors_compass": 1,
	&"relic.wayfarers_satchel": 1, &"relic.village_green": 1,
	&"relic.ferry_rights": 1, &"relic.mixed_use_charter": 2,
	&"relic.historic_routes": 2, &"relic.stewards_relay": 2,
	&"relic.one_great_city": 3, &"relic.the_long_road": 3,
}
const TIERS: Array[StringName] = [&"foundational", &"developed", &"legacy"]


static func validate(definitions: Array[RelicDefinition]) -> ValidationResult:
	if definitions.size() != ROSTER.size():
		return ValidationResult.failure(&"invalid_relic_roster", "Alpha requires exactly ten Relics.")
	var seen: Array[StringName] = []
	for definition: RelicDefinition in definitions:
		if definition == null or definition.definition_id not in ROSTER:
			return ValidationResult.failure(&"invalid_relic_roster", "Missing or deferred Relic in alpha pool.")
		if definition.definition_id in seen:
			return ValidationResult.failure(&"duplicate_definition_id", "Relic IDs must be unique.")
		seen.append(definition.definition_id)
		var act: int = ROSTER[definition.definition_id]
		var suffix: StringName = StringName(String(definition.definition_id).trim_prefix("relic."))
		if definition.display_name.strip_edges().is_empty() or definition.behavior_id != suffix \
				or definition.unlock_act != act or definition.tier != TIERS[act - 1] \
				or definition.once_per_act != (definition.definition_id == &"relic.boundary_stones"):
			return ValidationResult.failure(&"invalid_relic_configuration", "Relic tier or behavior differs from canonical alpha.")
	return ValidationResult.success()
