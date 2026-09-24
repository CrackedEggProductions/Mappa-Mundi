class_name SpecialistState
extends RefCounted
## Run-owned roster plus structured effects/training audit and deferred reward handoff.

var pieces: Array[SpecialistPieceState] = []
var history: Array[Dictionary] = []
var deferred_rewards: Array[Dictionary] = []


func piece(id: int) -> SpecialistPieceState:
	for value: SpecialistPieceState in pieces:
		if value != null and value.piece_id == id:
			return value
	return null
