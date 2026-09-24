class_name SpecialistValueCodec
extends RefCounted
## Typed primitive tree for continuation snapshots. Every integer uses decimal text,
## including nested IDs and dictionary keys; no JSON double can round a runtime ID.


static func encode(value: Variant) -> Dictionary:
	if value == null:
		return {"type": "nil"}
	if value is bool:
		return {"type": "bool", "value": value}
	if value is int:
		return {"type": "int", "value": str(value)}
	if value is float:
		return {"type": "float", "value": value}
	if value is StringName:
		return {"type": "name", "value": String(value)}
	if value is String:
		return {"type": "string", "value": value}
	if value is Vector2i:
		return {"type": "coordinate", "value": [str(value.x), str(value.y)]}
	if value is Array:
		var entries: Array[Dictionary] = []
		for entry: Variant in value:
			entries.append(encode(entry))
		return {"type": "array", "value": entries}
	if value is Dictionary:
		var pairs: Array[Dictionary] = []
		for key: Variant in value:
			pairs.append({"key": encode(key), "value": encode(value[key])})
		pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return JSON.stringify(a["key"], "", true) < JSON.stringify(b["key"], "", true))
		return {"type": "dictionary", "value": pairs}
	assert(false, "Specialist continuation may contain only serializable primitive state")
	return {}


static func valid(value: Variant, depth: int = 0) -> bool:
	if depth > 128 or not value is Dictionary or not value.get("type") is String:
		return false
	var kind: String = value["type"]
	if kind == "nil":
		return value.size() == 1
	if not RunSerializer._has_exact_keys(value, ["type", "value"]):
		return false
	var payload: Variant = value["value"]
	match kind:
		"bool": return payload is bool
		"int": return RunSerializer._is_decimal_int64(payload)
		"float": return (payload is float or payload is int) and is_finite(float(payload))
		"string", "name": return payload is String
		"coordinate":
			return payload is Array and payload.size() == 2 \
				and RunSerializer._is_decimal_int64(payload[0]) \
				and RunSerializer._is_decimal_int64(payload[1]) \
				and String(payload[0]).to_int() >= -2147483648 and String(payload[0]).to_int() <= 2147483647 \
				and String(payload[1]).to_int() >= -2147483648 and String(payload[1]).to_int() <= 2147483647
		"array":
			if not payload is Array:
				return false
			for entry: Variant in payload:
				if not valid(entry, depth + 1):
					return false
			return true
		"dictionary":
			if not payload is Array:
				return false
			var keys: Dictionary = {}
			for pair: Variant in payload:
				if not RunSerializer._has_exact_keys(pair, ["key", "value"]) \
						or not valid(pair["key"], depth + 1) or not valid(pair["value"], depth + 1):
					return false
				if pair["key"]["type"] not in ["string", "name", "int", "coordinate"]:
					return false
				var key: Variant = decode(pair["key"])
				if keys.has(key):
					return false
				keys[key] = true
			return true
	return false


static func decode(value: Dictionary) -> Variant:
	var payload: Variant = value.get("value")
	match value["type"]:
		"nil": return null
		"bool", "string": return payload
		"int": return String(payload).to_int()
		"float": return float(payload)
		"name": return StringName(payload)
		"coordinate": return Vector2i(String(payload[0]).to_int(), String(payload[1]).to_int())
		"array":
			var entries: Array = []
			for entry: Dictionary in payload:
				entries.append(decode(entry))
			return entries
		"dictionary":
			var dictionary: Dictionary = {}
			for pair: Dictionary in payload:
				dictionary[decode(pair["key"])] = decode(pair["value"])
			return dictionary
	return null
