extends SceneTree
## Non-canonical access diagnostic: 10,000 independent seeded offers per Act.
## No acquisition, adaptive weighting, tuning or assertions about balance.

const SAMPLE_COUNT: int = 10000


func _initialize() -> void:
	var content: ContentRegistry = ContentRegistry.new()
	assert(content.load_phase_nine().is_valid)
	var report: Dictionary = {"sample_count_per_act": SAMPLE_COUNT, "seed_range": [1, SAMPLE_COUNT],
		"policy": "One normal weighted offer per independent seed; no Relics acquired; all eligible candidates retained between samples.",
		"weights_per_relic": {"common": 60, "uncommon": 30, "rare": 10}, "acts": {}}
	for act: int in [1, 2]:
		report.acts[str(act)] = _sample_act(content, act)
	var output: String = JSON.stringify(report, "\t")
	print(output)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var file: FileAccess = FileAccess.open(argument.trim_prefix("--output="), FileAccess.WRITE)
			assert(file != null)
			file.store_string(output + "\n")
	quit()


func _sample_act(content: ContentRegistry, act: int) -> Dictionary:
	var appearances: Dictionary = {}
	var rarity_slots: Dictionary = {"common": 0, "uncommon": 0, "rare": 0}
	var offers_with: Dictionary = {"common": 0, "uncommon": 0, "rare": 0}
	for id: StringName in content.get_relic_ids():
		appearances[String(id)] = 0
	for seed_value: int in range(1, SAMPLE_COUNT + 1):
		var state: RunState = RunState.new(seed_value)
		state.expansion = ExpansionState.new()
		state.expansion.current_act = act
		state.relics = RelicState.new()
		var offer: Array[StringName] = RewardRules.sample_relics(state, RelicRules.eligible_ids(state, content), content)
		var present: Array[String] = []
		for id: StringName in offer:
			appearances[String(id)] += 1
			var rarity: String = String(content.get_relic(id).rarity)
			rarity_slots[rarity] += 1
			if rarity not in present:
				present.append(rarity)
		for rarity: String in present:
			offers_with[rarity] += 1
	var appearance_percent: Dictionary = {}
	var offer_percent: Dictionary = {}
	var slot_percent: Dictionary = {}
	for id: String in appearances:
		appearance_percent[id] = 100.0 * float(appearances[id]) / SAMPLE_COUNT
	for rarity: String in rarity_slots:
		offer_percent[rarity] = 100.0 * float(offers_with[rarity]) / SAMPLE_COUNT
		slot_percent[rarity] = 100.0 * float(rarity_slots[rarity]) / (3 * SAMPLE_COUNT)
	return {"individual_appearance_percent": appearance_percent,
		"offer_with_at_least_one_percent": offer_percent, "slot_rarity_percent": slot_percent,
		"individual_counts": appearances, "rarity_slot_counts": rarity_slots}
