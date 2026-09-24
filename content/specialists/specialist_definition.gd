class_name SpecialistDefinition
extends Resource
## Passive alpha role metadata. SpecialistRules owns structural behavior.

@export var definition_id: StringName = &""
@export var display_name: String = ""
@export var behavior_id: StringName = &""
@export var eligible_feature_types: Array[DomainTypes.FeatureType] = []
