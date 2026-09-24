class_name RelicState
extends RefCounted
## Complete acquired/exhausted history, including former equipped Relics.

var instances: Array[RelicInstanceState] = []
var capacity: int = 2
var current_act: int = 1
var normal_surveys_used: int = 0
var history: Array[Dictionary] = []
