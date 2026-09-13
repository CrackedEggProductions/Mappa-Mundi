class_name TileDefinition
extends Resource
## Passive static design, never a physical tile copy or current board geometry.

@export var definition_id: StringName = &""
@export var display_name: String = ""
@export var tile_class: DomainTypes.TileClass = DomainTypes.TileClass.EXPANSION
@export var unlock_act: int = 1
@export var reward_class: DomainTypes.RewardClass = DomainTypes.RewardClass.NONE
## Canonical orientation in North/East/South/West order.
@export var canonical_edges: Array[DomainTypes.EdgeType] = []
@export var feature_groups: Array[TileFeatureGroup] = []
@export var relationships: Array[TileFeatureRelationship] = []
## Explicit same-tile Settlement/Field meeting, independent of tracked feature groups.
@export var field_supports_settlement: bool = false
@export var placement_behavior_id: StringName = &""
@export var effect_behavior_id: StringName = &""
@export var development_family_id: StringName = &""
@export var upgrade_from_definition_id: StringName = &""
@export var tags: Array[StringName] = []
