class_name RunSeedSource
extends RefCounted
## Initial entropy only. Gameplay randomness belongs exclusively to RunRNG.


static func generate() -> int:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(8)
	assert(bytes.size() == 8, "The operating system must provide New Run seed entropy")
	return bytes.decode_s64(0)


static func parse(text: String) -> Dictionary:
	var value: String = text.strip_edges()
	var negative: bool = value.begins_with("-")
	var digits: String = value.substr(1) if negative or value.begins_with("+") else value
	if digits.is_empty():
		return {"valid": false}
	for index: int in range(digits.length()):
		var character: int = digits.unicode_at(index)
		if character < 48 or character > 57:
			return {"valid": false}
	while digits.length() > 1 and digits.begins_with("0"):
		digits = digits.substr(1)
	var limit: String = "9223372036854775808" if negative else "9223372036854775807"
	if digits.length() > limit.length() or (digits.length() == limit.length() and digits > limit):
		return {"valid": false}
	return {"valid": true, "seed": (("-" if negative else "") + digits).to_int()}
