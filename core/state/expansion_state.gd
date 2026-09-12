class_name ExpansionState
extends RefCounted
## Authoritative spatial/turn state. Charter and later feature history are deferred.

var board: BoardState = BoardState.new()
## Index zero is the next bag draw. Hand indices are stable slots.
var bag: Array[int] = []
var hand: Array[int] = []
var reserve_id: int = 0
var removed_ids: Array[int] = []
var current_act: int = 1
var normal_placements: int = 0
var survey_charges: int = 1
var state_revision: int = 0
## Zero marks a consumed hand slot only while its engine-owned refill is pending.
var pending_refill_index: int = -1
