class_name SpecialistContentValidator
extends RefCounted
## Canonical trainable pool; content selects behavior, never supplies executable rules.

const ROLES: Dictionary = {
	&"specialist.merchant": DomainTypes.FeatureType.ROAD,
	&"specialist.cartographer": DomainTypes.FeatureType.ROAD,
	&"specialist.architect": DomainTypes.FeatureType.SETTLEMENT,
	&"specialist.homesteader": DomainTypes.FeatureType.SETTLEMENT,
	&"specialist.naturalist": DomainTypes.FeatureType.FOREST,
	&"specialist.forester": DomainTypes.FeatureType.FOREST,
	&"specialist.riverkeeper": DomainTypes.FeatureType.RIVER,
	&"specialist.harbormaster": DomainTypes.FeatureType.RIVER,
}


static func validate(definitions: Array[SpecialistDefinition]) -> ValidationResult:
	if definitions.size() != ROLES.size():
		return ValidationResult.failure(&"invalid_specialist_roster", "Alpha requires exactly eight trained roles.")
	var seen: Array[StringName] = []
	for definition: SpecialistDefinition in definitions:
		if definition == null or definition.definition_id not in ROLES:
			return ValidationResult.failure(&"invalid_specialist_roster", "Missing or deferred Specialist in alpha pool.")
		if definition.definition_id in seen:
			return ValidationResult.failure(&"duplicate_definition_id", "Specialist IDs must be unique.")
		seen.append(definition.definition_id)
		var suffix: StringName = StringName(String(definition.definition_id).trim_prefix("specialist."))
		if definition.behavior_id != suffix or definition.display_name.strip_edges().is_empty() \
				or definition.eligible_feature_types.size() != 1 \
				or definition.eligible_feature_types[0] != ROLES[definition.definition_id]:
			return ValidationResult.failure(&"invalid_specialist_configuration", "Specialist behavior or target differs from canonical alpha.")
	return ValidationResult.success()
