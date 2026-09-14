class_name CompletionSnapshot
extends RefCounted
## Primitive-only deep-owned package. Access returns copies, never mutable peers.

var _frozen: Dictionary = {}


func _init(data: Dictionary = {}) -> void:
	_frozen = data.duplicate(true)
	_freeze(_frozen)


func data() -> Dictionary:
	return _frozen.duplicate(true)


static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for key: Variant in value:
			_freeze(value[key])
		value.make_read_only()
	elif value is Array:
		for item: Variant in value:
			_freeze(item)
		value.make_read_only()
