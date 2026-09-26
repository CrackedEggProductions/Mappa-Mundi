class_name ResolutionResult
extends RefCounted
## Non-authoritative command report. Rules finish before consumers animate it.

var validation: ValidationResult
var cues: Array[Dictionary] = []
var track_deltas: Array[int] = [0, 0, 0, 0]
var previous_act: int = 1
var previous_grand_revealed: bool = false
var phase: GamePhase.Type = GamePhase.Type.SETUP
