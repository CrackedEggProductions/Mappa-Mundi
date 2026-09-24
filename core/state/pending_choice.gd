class_name PendingChoice
extends RefCounted
## Persist exact options; loading never regenerates an RNG-dependent offer.

var choice_id: int = 0
var kind: StringName = &""
var options: Array[Dictionary] = []
var context: Dictionary = {}
