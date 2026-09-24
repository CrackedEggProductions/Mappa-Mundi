class_name RelicInstanceState
extends RefCounted
## Acquisition identity survives replacement; a removed instance grants no effects.

var runtime_id: int = 0
var definition_id: StringName = &""
var acquisition_order: int = 0
var acquired_act: int = 1
var equipped_slot: int = -1
var use_act: int = 1
var uses_remaining: int = 0
var removed_act: int = 0
var once_per_act: bool = false
