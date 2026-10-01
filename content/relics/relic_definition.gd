class_name RelicDefinition
extends Resource
## Passive canonical alpha content; executable rules remain in RelicRules.

const OFFER_WEIGHTS: Dictionary = {&"common": 60, &"uncommon": 30, &"rare": 10}

@export var definition_id: StringName = &""
@export var display_name: String = ""
@export var minimum_act: int = 0
@export var behavior_id: StringName = &""

@export var rarity: StringName = &""
@export var once_per_act: bool = false


func offer_weight() -> int:
	return int(OFFER_WEIGHTS.get(rarity, 0))
