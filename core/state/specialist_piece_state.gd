class_name SpecialistPieceState
extends RefCounted
## Physical piece identity survives permanent training and legal feature mergers.

enum Status { AVAILABLE = 0, ASSIGNED = 1 }

var piece_id: int = 0
## Empty identifies a generic Steward; no separate disposable generic piece exists.
var role_definition_id: StringName = &""
var status: Status = Status.AVAILABLE
var assigned_target_type: int = -1
var assigned_target_id: int = 0
var assigned_act: int = 0
var assigned_placement_index: int = 0
var growth_baseline_component_ids: Array[int] = []
var qualifying_component_ids: Array[int] = []
var training_history: Array[Dictionary] = []
