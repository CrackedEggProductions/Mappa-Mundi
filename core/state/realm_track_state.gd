class_name RealmTrackState
extends RefCounted
## Cumulative Population, Trade, Culture, Ecology. No spending or threshold effects.

var values: Array[int] = [0, 0, 0, 0]


func get_value(track: DomainTypes.TrackType) -> int:
	return values[track]


func add(track: DomainTypes.TrackType, amount: int) -> void:
	assert(amount >= 0 and values[track] <= 9223372036854775807 - amount)
	values[track] += amount
