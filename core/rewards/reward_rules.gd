class_name RewardRules
extends RefCounted
## One serializable queue for milestones, thresholds and nested reward chains.

const THRESHOLDS: Array[int] = [20, 40, 70, 100]
const THRESHOLD_KINDS: Array[StringName] = [&"tile_reward", &"training_reward", &"relic_offer", &"major_reward"]
const MILESTONE_TYPES: Array[int] = [1, 0, 2, 3]
const MILESTONE_NAMES: Array[StringName] = [&"settlement", &"road", &"forest", &"river"]
const MAJOR_OPTIONS: Array[StringName] = [&"grand_survey", &"masterwork", &"recruit_steward", &"relic_cache"]


static func record(state: RunState, kind: StringName, details: Dictionary = {}, source_id: int = 0) -> void:
	state.rewards.history.append({"event_id": state.id_allocator.allocate(), "kind": String(kind),
		"source_id": source_id, "act": state.expansion.current_act, "details": details.duplicate(true)})


static func enqueue(state: RunState, kind: StringName, source_id: int = 0,
		eligibility_act: int = 0) -> void:
	state.rewards.queue.append({"kind": String(kind), "source_id": source_id,
		"eligibility_act": eligibility_act if eligibility_act > 0 else state.expansion.current_act})


static func queue_completion(state: RunState, snapshot: CompletionSnapshot) -> void:
	if state.rewards == null:
		return
	var data: Dictionary = snapshot.data()
	for index: int in range(MILESTONE_TYPES.size()):
		var milestone: StringName = MILESTONE_NAMES[index]
		if state.rewards.milestone_flags.has(milestone):
			continue
		for facts: Dictionary in data.get("features", []):
			if int(facts["feature_type"]) != MILESTONE_TYPES[index]:
				continue
			var qualifies: bool = int(facts["total_size"]) >= (8 if index == 0 else 10)
			if index == 1:
				qualifies = facts.get("network_settlement_ids", []).size() >= 5
			if qualifies:
				state.rewards.milestone_flags.append(milestone)
				record(state, &"milestone_earned", {"milestone": String(milestone),
					"lineage_id": int(facts["lineage_id"])}, int(data.get("source_id", 0)))
				enqueue(state, &"relic_offer", int(data.get("source_id", 0)), int(data["act"]))
				break
	enqueue(state, &"scan_thresholds", int(data.get("source_id", 0)))


static func queue_thresholds(state: RunState, source_id: int = 0) -> void:
	for track: int in range(4):
		for index: int in range(THRESHOLDS.size()):
			var threshold: int = THRESHOLDS[index]
			var key: String = "%d:%d" % [track, threshold]
			if state.features.tracks.values[track] < threshold or state.rewards.threshold_flags.has(key):
				continue
			state.rewards.threshold_flags.append(key)
			record(state, &"track_threshold_crossed", {"track": track, "threshold": threshold}, source_id)
			var job: Dictionary = {"kind": String(THRESHOLD_KINDS[index]), "source_id": source_id,
				"eligibility_act": state.expansion.current_act, "track": track, "threshold": threshold}
			state.rewards.queue.append(job)


static func claim_deferred_training(state: RunState) -> void:
	if state.rewards == null or state.specialists == null:
		return
	for deferred: Dictionary in state.specialists.deferred_rewards:
		if deferred.get("reward_kind", "") == "normal_tile_reward":
			for index: int in range(int(deferred.get("quantity", 1))):
				enqueue(state, &"tile_reward", int(deferred.get("event_id", 0)))
	state.specialists.deferred_rewards.clear()


static func advance(state: RunState, content: ContentRegistry) -> void:
	if state.rewards == null or state.pending_choice != null:
		return
	while not state.rewards.queue.is_empty() and state.pending_choice == null:
		var job: Dictionary = state.rewards.queue.pop_front()
		var kind: StringName = StringName(job["kind"])
		match kind:
			&"scan_thresholds":
				queue_thresholds(state, int(job.get("source_id", 0)))
			&"tile_reward", &"masterwork":
				var ids: Array[StringName] = tile_pool(content, int(job["eligibility_act"]), kind == &"masterwork")
				_offer_ids(state, kind, ids, "definition_id", job)
			&"relic_offer":
				var ids: Array[StringName] = RelicRules.eligible_ids(state, content, int(job["eligibility_act"]))
				if ids.is_empty():
					_prepend(state, &"tile_reward", job)
				else:
					_offer_ids(state, kind, ids, "definition_id", job)
			&"major_reward":
				_offer_ids(state, kind, major_pool(state, content, int(job["eligibility_act"])), "major_id", job)
			&"training_reward":
				var trainable: Array[int] = SpecialistRules.trainable_piece_ids(state)
				if trainable.is_empty():
					_prepend(state, &"tile_reward", job)
				else:
					var options: Array[Dictionary] = []
					for piece_id: int in trainable:
						options.append({"piece_id": piece_id})
					create_choice(state, &"training_piece", options, job)


static func tile_pool(content: ContentRegistry, eligibility_act: int, masterwork: bool = false) -> Array[StringName]:
	var result: Array[StringName] = []
	for definition_id: StringName in content.get_tile_ids():
		var tile: TileDefinition = content.get_tile(definition_id)
		if tile.unlock_act > eligibility_act or tile.reward_class == DomainTypes.RewardClass.NONE:
			continue
		if masterwork and not masterwork_eligible(tile):
			continue
		result.append(definition_id)
	return result


static func masterwork_eligible(tile: TileDefinition) -> bool:
	# RULE-REWARD-MAJOR-003: Upgrades qualify, ordinary Developments do not.
	return tile.tile_class == DomainTypes.TileClass.UPGRADE or tile.reward_class in [
		DomainTypes.RewardClass.SPECIALIZED_EXPANSION, DomainTypes.RewardClass.MAJOR_RARE]


static func copy_quantity(tile: TileDefinition) -> int:
	match tile.reward_class:
		DomainTypes.RewardClass.BASIC_EXPANSION: return 3
		DomainTypes.RewardClass.SPECIALIZED_EXPANSION, DomainTypes.RewardClass.ORDINARY_DEVELOPMENT: return 2
		DomainTypes.RewardClass.MAJOR_RARE: return 1
	return 0


static func major_pool(state: RunState, content: ContentRegistry, eligibility_act: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for option: StringName in MAJOR_OPTIONS:
		if option == &"recruit_steward" and state.specialists.pieces.size() >= SpecialistRules.HARD_CAP:
			continue
		if option == &"relic_cache" and RelicRules.eligible_ids(state, content, eligibility_act).is_empty():
			continue
		if option == &"masterwork" and tile_pool(content, eligibility_act, true).is_empty():
			continue
		result.append(option)
	return result


static func sample(state: RunState, ids: Array[StringName], purpose: StringName) -> Array[StringName]:
	var pool: Array[StringName] = ids.duplicate()
	pool.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	if pool.size() <= 3:
		return pool
	var offered: Array[StringName] = []
	for index: int in range(3):
		var selected: StringName = state.rng.choose_definition_id(pool, purpose)
		offered.append(selected)
		pool.erase(selected)
	return offered


static func create_choice(state: RunState, kind: StringName, options: Array[Dictionary], context: Dictionary) -> void:
	assert(not options.is_empty(), "A reward must have at least one valid option")
	var choice: PendingChoice = PendingChoice.new()
	choice.choice_id = state.id_allocator.allocate()
	choice.kind = kind
	choice.options = options.duplicate(true)
	choice.context = context.duplicate(true)
	state.pending_choice = choice
	state.phase = GamePhase.Type.PENDING_CHOICE
	record(state, &"relic_offered" if kind == &"relic_offer" else &"reward_offered",
		{"choice_id": choice.choice_id, "kind": String(kind), "options": options.duplicate(true)}, int(context.get("source_id", 0)))


static func _offer_ids(state: RunState, kind: StringName, ids: Array[StringName], key: String, context: Dictionary) -> void:
	var options: Array[Dictionary] = []
	for definition_id: StringName in sample(state, ids, StringName(String(kind) + "_offer")):
		options.append({key: String(definition_id)})
	create_choice(state, kind, options, context)


static func _prepend(state: RunState, kind: StringName, context: Dictionary) -> void:
	var job: Dictionary = context.duplicate(true)
	job["kind"] = String(kind)
	state.rewards.queue.push_front(job)
