class_name PhaseEightInvariantValidator
extends RefCounted
## Checks authoritative values without acquiring, offering, refreshing or replaying.

const MILESTONES: Array[StringName] = [&"settlement", &"road", &"forest", &"river"]


static func validate(state: RunState, content: ContentRegistry, report: InvariantReport) -> void:
	if state.expansion != null:
		RelicGeometry.validate_boundaries(state, report)
	if state.relics == null and state.rewards == null:
		return
	if state.relics == null or state.rewards == null or state.expansion == null \
			or state.features == null or state.specialists == null or content.get_relic_ids().size() != 10:
		report.add(&"missing_phase_eight_state", "Relics and rewards require the complete Phase-8 profile.")
		return
	_validate_relics(state, content, report)
	if not report.is_valid:
		return
	_validate_rewards(state, report)
	if not report.is_valid:
		return
	_validate_continuation(state, report)
	if not report.is_valid:
		return
	_validate_choice(state, content, report)


static func _validate_relics(state: RunState, content: ContentRegistry, report: InvariantReport) -> void:
	var relics: RelicState = state.relics
	if relics.current_act not in [1, 2, 3] or relics.current_act != state.expansion.current_act \
			or relics.capacity != [2, 4, 5][clampi(relics.current_act - 1, 0, 2)] \
			or relics.normal_surveys_used < 0:
		report.add(&"invalid_relic_capacity", "Relic capacity and use epoch must match the current Act.")
	var ids: Array[int] = SpecialistInvariantValidator._occupied_ids(state)
	for piece: SpecialistPieceState in state.specialists.pieces:
		ids.append(piece.piece_id)
	if state.pending_choice != null:
		ids.append(state.pending_choice.choice_id)
	var definitions: Array[StringName] = []
	var orders: Array[int] = []
	var slots: Array[int] = []
	for instance: RelicInstanceState in relics.instances:
		if instance == null:
			report.add(&"invalid_relic_instance", "Null Relic acquisition record.")
			continue
		_check_id(state, instance.runtime_id, ids, report)
		var definition: RelicDefinition = content.get_relic(instance.definition_id)
		if definition == null or instance.definition_id in definitions:
			report.add(&"invalid_relic_definition", "Acquired Relics must be unique canonical definitions.", instance.runtime_id)
			continue
		definitions.append(instance.definition_id)
		if instance.acquisition_order < 1 or instance.acquisition_order in orders:
			report.add(&"invalid_relic_order", "Relic acquisition orders must be positive and unique.", instance.runtime_id)
		orders.append(instance.acquisition_order)
		if instance.acquired_act < definition.unlock_act or instance.acquired_act > relics.current_act \
				or instance.use_act < instance.acquired_act or instance.use_act > relics.current_act \
				or instance.once_per_act != definition.once_per_act \
				or instance.uses_remaining not in [0, 1] \
				or (not instance.once_per_act and instance.uses_remaining != 0):
			report.add(&"invalid_relic_use", "Relic acquisition/tier/use state is inconsistent.", instance.runtime_id)
		if instance.equipped_slot >= 0:
			if instance.equipped_slot >= relics.capacity or instance.equipped_slot in slots \
					or instance.removed_act != 0 or instance.use_act != relics.current_act:
				report.add(&"invalid_relic_slot", "Equipped Relics require unique legal slots and a current use epoch.", instance.runtime_id)
			slots.append(instance.equipped_slot)
		elif instance.equipped_slot != -1 or instance.removed_act < instance.acquired_act \
				or instance.removed_act > relics.current_act:
			report.add(&"invalid_removed_relic", "Unequipped acquired Relics require replacement history.", instance.runtime_id)
	orders.sort()
	for index: int in range(orders.size()):
		if orders[index] != index + 1:
			report.add(&"invalid_relic_order", "Acquisition order cannot omit historical acquisitions.")
	_validate_audit(state, relics.history, ids, report, true)
	_validate_audit(state, state.rewards.history, ids, report)
	if report.is_valid:
		_validate_acquisition_history(state, report)


static func _validate_acquisition_history(state: RunState, report: InvariantReport) -> void:
	for instance: RelicInstanceState in state.relics.instances:
		var acquisitions: int = 0
		var replacements: int = 0
		var spent: int = 0
		for event: Dictionary in state.relics.history:
			if event["source_id"] != instance.runtime_id:
				continue
			var details: Dictionary = event["details"]
			if event["kind"] == "relic_acquired":
				acquisitions += 1
				if details.get("definition_id") != String(instance.definition_id) \
						or details.get("acquisition_order") != instance.acquisition_order \
						or event["act"] != instance.acquired_act:
					report.add(&"invalid_relic_acquisition_history", "Relic identity must agree with its acquisition audit.")
			elif event["kind"] == "relic_replaced":
				replacements += 1
				if details.get("definition_id") != String(instance.definition_id) or event["act"] != instance.removed_act:
					report.add(&"invalid_relic_replacement_history", "Removed Relic must agree with replacement audit.")
			elif event["kind"] == "relic_use_consumed" and event["act"] == instance.use_act:
				spent += 1
		if acquisitions != 1 or replacements != (1 if instance.equipped_slot == -1 else 0):
			report.add(&"invalid_relic_acquisition_history", "Every acquired/removed Relic requires its unique lifetime events.")
		if instance.once_per_act and (spent not in [0, 1] or instance.uses_remaining != 1 - spent):
			report.add(&"invalid_relic_use_history", "Once-per-Act remaining use must agree with consumption history.")


static func _check_id(state: RunState, id: int, ids: Array[int], report: InvariantReport) -> void:
	if id <= 0 or id >= state.next_runtime_id or id in ids:
		report.add(&"invalid_phase_eight_id", "Phase-8 IDs must be unique allocated run-local identities.", id)
	ids.append(id)


static func _validate_audit(state: RunState, history: Array[Dictionary], ids: Array[int], report: InvariantReport,
		allow_scoring_mirrors: bool = false) -> void:
	var events: Array[int] = []
	for entry: Dictionary in history:
		if not entry.get("event_id") is int or not (entry.get("kind") is StringName or entry.get("kind") is String) \
				or not entry.get("source_id") is int or not entry.get("act") is int \
				or not entry.get("details") is Dictionary:
			report.add(&"invalid_phase_eight_history", "Audit events require typed IDs, kind, Act and details.")
			continue
		if entry["event_id"] in events:
			report.add(&"duplicate_phase_eight_history", "Audit registries cannot duplicate the same physical event.")
		events.append(entry["event_id"])
		if allow_scoring_mirrors and entry["kind"] == "relic_triggered" and entry["event_id"] in ids:
			_validate_trigger_audit(state, entry, report)
		else:
			_check_id(state, entry["event_id"], ids, report)
		if String(entry["kind"]).is_empty() or entry["act"] < 1 or entry["act"] > state.expansion.current_act:
			report.add(&"invalid_phase_eight_history", "Audit kind and Act must be valid.")


static func _validate_trigger_audit(state: RunState, entry: Dictionary, report: InvariantReport) -> void:
	var details: Dictionary = entry["details"]
	var trigger: FeatureHistoryRecord = null
	for event: FeatureHistoryRecord in state.features.history:
		if event.event_id == entry["event_id"] and event.kind == &"relic_triggered":
			trigger = event
	if trigger == null or trigger.source_id != entry["source_id"] \
			or trigger.lineage_id != details.get("target_id") or trigger.feature_type != details.get("target_type") \
			or trigger.act != entry["act"] or not SpecialistSerializer._integers(details.get("gains")) \
			or details.get("gains", []).size() != 4:
		report.add(&"invalid_relic_trigger_audit", "Relic scoring audit must mirror its exact completion child event.")
		return
	var gains: Array[int] = [0, 0, 0, 0]
	for event: FeatureHistoryRecord in state.features.history:
		if event.kind == &"realm_track_changed" and event.parent_event_id == trigger.event_id \
				and event.track in [0, 1, 2, 3]:
			gains[event.track] += event.amount
	if gains != details["gains"]:
		report.add(&"invalid_relic_trigger_audit", "Relic audit gains must equal its committed track events.")


static func _validate_rewards(state: RunState, report: InvariantReport) -> void:
	var seen: Array[String] = []
	for flag: String in state.rewards.threshold_flags:
		var valid: bool = false
		for track: int in range(4):
			for threshold: int in [20, 40, 70, 100]:
				if flag == "%d:%d" % [track, threshold]:
					valid = true
		if not valid or flag in seen:
			report.add(&"invalid_threshold_flag", "Threshold flags must be unique canonical Track/threshold pairs.")
		seen.append(flag)
	var milestones: Array[StringName] = []
	for flag: StringName in state.rewards.milestone_flags:
		if flag not in MILESTONES or flag in milestones:
			report.add(&"invalid_milestone_flag", "Milestone flags must be unique canonical feature types.")
		milestones.append(flag)
	for job: Dictionary in state.rewards.queue:
		var required: Array[String] = ["kind", "source_id", "eligibility_act"]
		if job.has("track") or job.has("threshold"):
			required.append_array(["track", "threshold"])
		if not RunSerializer._has_exact_keys(job, required) or not job.get("source_id") is int \
				or job.get("source_id", -1) < 0 or job.get("source_id", 0) >= state.next_runtime_id:
			report.add(&"invalid_reward_job", "Reward jobs require complete typed source and eligibility context.")
			continue
		if not (job.get("kind") is String or job.get("kind") is StringName) \
				or String(job.get("kind", "")) not in ["scan_thresholds", "tile_reward", "masterwork", "relic_offer", "major_reward", "training_reward"]:
			report.add(&"invalid_reward_job", "Queued rewards require a typed canonical work kind.")
		if not job["eligibility_act"] is int or job["eligibility_act"] not in [1, 2, 3] \
				or job["eligibility_act"] > state.expansion.current_act:
			report.add(&"invalid_reward_act", "Reward eligibility must freeze a legal alpha Act.")
		if job.has("track") and (not job["track"] is int or not job["threshold"] is int \
				or job["track"] not in [0, 1, 2, 3] or job["threshold"] not in [20, 40, 70, 100]):
			report.add(&"invalid_threshold_job", "Queued threshold context must identify a canonical threshold.")
	_validate_reward_flags(state, report)


static func _validate_reward_flags(state: RunState, report: InvariantReport) -> void:
	var thresholds: Array[String] = []
	var milestones: Array[StringName] = []
	for event: Dictionary in state.rewards.history:
		var details: Dictionary = event["details"]
		if event["kind"] == "track_threshold_crossed":
			if not details.get("track") is int or not details.get("threshold") is int \
					or details["track"] not in [0, 1, 2, 3] or details["threshold"] not in [20, 40, 70, 100]:
				report.add(&"invalid_threshold_history", "Threshold audit requires a canonical Track and threshold.")
				continue
			var flag: String = "%d:%d" % [details["track"], details["threshold"]]
			if flag in thresholds:
				report.add(&"duplicate_threshold_history", "Each threshold may be awarded only once per run.")
			thresholds.append(flag)
		elif event["kind"] == "milestone_earned":
			if not (details.get("milestone") is String or details.get("milestone") is StringName):
				report.add(&"invalid_milestone_history", "Milestone audit requires a canonical feature kind.")
				continue
			var flag: StringName = StringName(details["milestone"])
			if flag in milestones or flag not in MILESTONES:
				report.add(&"invalid_milestone_history", "Each canonical milestone may be awarded only once.")
			milestones.append(flag)
	var actual_thresholds: Array[String] = state.rewards.threshold_flags.duplicate()
	var actual_milestones: Array[StringName] = state.rewards.milestone_flags.duplicate()
	thresholds.sort()
	milestones.sort()
	actual_thresholds.sort()
	actual_milestones.sort()
	if actual_thresholds != thresholds or actual_milestones != milestones:
		report.add(&"reward_flag_history_mismatch", "Awarded flags must exactly preserve the one-time reward audit.")


static func _validate_continuation(state: RunState, report: InvariantReport) -> void:
	var resolution: ResolutionState = state.resolution
	if resolution == null:
		if not state.rewards.queue.is_empty():
			report.add(&"missing_reward_continuation", "Queued reward work needs a resumable continuation.")
		return
	if resolution.stage == &"specialist_assignment":
		return # Phase-7 validator checks the exact pre-completion snapshot.
	if resolution.stage not in [&"reward_queue", &"specialist_relay", &"compass"]:
		report.add(&"invalid_phase_eight_stage", "Only player-choice stages may be saved.")
		return
	if resolution.stage == &"compass":
		if not resolution.completion_snapshot.is_empty() or state.pending_choice == null or state.pending_choice.kind != &"compass":
			report.add(&"invalid_compass_continuation", "Compass continuation cannot replay a placement.")
		return
	if resolution.context.get("mode", "placement") == "reward":
		if resolution.stage != &"reward_queue" or not resolution.completion_snapshot.is_empty():
			report.add(&"invalid_reward_continuation", "Standalone rewards must not carry a completion replay.")
		return
	if resolution.context.get("base_applied") != true:
		report.add(&"unresolved_completion_stage", "Post-completion choices require committed base effects.")
	if resolution.stage == &"reward_queue" and (resolution.context.get("relics_applied") != true \
			or resolution.context.get("rewards_queued") != true):
		report.add(&"unresolved_relic_stage", "Reward choices follow completed Relic and milestone processing.")
	var snapshot: Dictionary = resolution.completion_snapshot
	if snapshot.get("source_id") != resolution.source_id or snapshot.get("act") != state.expansion.current_act:
		report.add(&"invalid_completed_snapshot", "Frozen completion source and Act must match its continuation.")
		return
	var snapshot_id: Variant = resolution.context.get("snapshot_event_id", 0)
	if not snapshot_id is int:
		report.add(&"invalid_completed_snapshot", "Completion snapshot event identity must be an integer.")
		return
	var facts: Array = snapshot.get("features", []).duplicate()
	facts.append_array(snapshot.get("enclosures", []))
	if facts.is_empty():
		if snapshot_id != 0:
			report.add(&"invalid_completed_snapshot", "An empty completion batch cannot claim a scored event.")
		return
	var records: Array[FeatureCompletionRecord] = []
	for record: FeatureCompletionRecord in state.features.completions:
		if record.snapshot_id == snapshot_id:
			records.append(record)
	if records.size() != facts.size():
		report.add(&"invalid_completed_snapshot", "Frozen batch must match its already-committed completion records.")
	for fact: Dictionary in facts:
		var found: bool = false
		for record: FeatureCompletionRecord in records:
			if record.lineage_id == fact.get("lineage_id", 0) and record.enclosure_id == fact.get("enclosure_id", 0):
				found = record.total_size == fact.get("total_size", record.total_size) \
					and record.component_ids == fact.get("component_ids", record.component_ids) \
					and record.source_id == (fact.get("source_id", 0) if record.enclosure_id != 0 else resolution.source_id)
		if not found:
			report.add(&"invalid_completed_snapshot", "Frozen feature identity/size differs from paid completion history.")
	if report.is_valid:
		_validate_frozen_batch(state, records, snapshot_id, report)


static func _validate_frozen_batch(state: RunState, records: Array[FeatureCompletionRecord], snapshot_id: int,
		report: InvariantReport) -> void:
	var snapshot: Dictionary = state.resolution.completion_snapshot
	var expected_features: Array[Dictionary] = []
	var expected_enclosures: Array[Dictionary] = []
	for record: FeatureCompletionRecord in records:
		if record.enclosure_id != 0:
			expected_enclosures.append({"enclosure_id": record.enclosure_id,
				"source_id": record.source_id, "stage": String(record.enclosure_stage),
				"natural_count": record.natural_neighbor_count, "settlement_count": record.settlement_neighbor_count})
			continue
		var facts: Dictionary = {}
		for key: String in ["lineage_id", "feature_type", "component_ids", "total_size", "first_completion",
				"growth_phase", "development_families", "new_component_ids", "field_support_ids", "river_support_ids",
				"forest_contact_ids", "new_field_ids", "new_river_ids", "new_forest_ids", "trade_network_id",
				"network_road_ids", "network_settlement_ids", "new_settlement_ids"]:
			facts[key] = record.get(key)
		facts["highest_settlement_class"] = record.highest_class_before_completion
		facts["undeveloped"] = record.forest_undeveloped
		expected_features.append(facts)
	if snapshot["features"] != expected_features or snapshot["enclosures"] != expected_enclosures:
		report.add(&"invalid_frozen_completion_facts", "Frozen base facts must exactly match all persisted completion facts.")
	var expected_relics: Dictionary = RelicRules.capture(state, TopologyService.rebuild(state))
	var historical_equipped: Array[Dictionary] = []
	for instance: RelicInstanceState in state.relics.instances:
		var acquired: bool = false
		var removed: bool = false
		for event: Dictionary in state.relics.history:
			if event["event_id"] >= snapshot_id or event["source_id"] != instance.runtime_id:
				continue
			if event["kind"] == "relic_acquired":
				acquired = true
			elif event["kind"] == "relic_replaced":
				removed = true
		if acquired and not removed:
			historical_equipped.append({"runtime_id": instance.runtime_id,
				"definition_id": String(instance.definition_id), "acquisition_order": instance.acquisition_order})
	historical_equipped.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["acquisition_order"] < b["acquisition_order"])
	expected_relics["equipped"] = historical_equipped
	var prior_record: int = 0
	for record: FeatureCompletionRecord in state.features.completions:
		if record.feature_type == DomainTypes.FeatureType.ROAD and record.snapshot_id < snapshot_id:
			prior_record = maxi(prior_record, record.total_size)
	expected_relics["prior_longest_road"] = prior_record
	if snapshot.get("relics") != expected_relics:
		report.add(&"invalid_frozen_relic_facts", "Frozen Relic geometry and ownership must match the completion's historical state.")
	var expected_specialists: Array[Dictionary] = []
	for event: FeatureHistoryRecord in state.features.history:
		if event.kind != &"specialist_triggered" or event.parent_event_id != snapshot_id:
			continue
		for audit: Dictionary in state.specialists.history:
			if audit.get("event_id") == event.event_id:
				var facts: Dictionary = audit.duplicate(true)
				for key: String in ["event_id", "kind", "act", "placement_index", "gains"]:
					facts.erase(key)
				expected_specialists.append(facts)
	if snapshot.get("specialists") != expected_specialists:
		report.add(&"invalid_frozen_specialist_facts", "Frozen Specialist facts must match the already-resolved batch audit.")


static func _validate_choice(state: RunState, content: ContentRegistry, report: InvariantReport) -> void:
	var choice: PendingChoice = state.pending_choice
	if choice == null or choice.kind in [&"specialist_assignment", &"specialist_training"]:
		return
	if state.resolution == null or state.phase != GamePhase.Type.PENDING_CHOICE:
		report.add(&"missing_phase_eight_choice_context", "Relic/reward choices require their continuation.")
		return
	if choice.kind == &"specialist_relay":
		if not StewardRelayRules.valid_choice(state):
			report.add(&"invalid_relay_choice", "Relay choice must match its returned piece and exact touching targets.")
		return
	if choice.kind in [&"compass", &"grand_survey"]:
		_validate_hand_choice(state, report)
		return
	if choice.kind not in RewardCommands.KINDS or state.resolution.stage != &"reward_queue":
		report.add(&"unknown_phase_eight_choice", "Unknown or misplaced reward choice.")
		return
	if not choice.context.get("eligibility_act") is int or choice.context["eligibility_act"] not in [1, 2, 3] \
			or choice.options.is_empty():
		report.add(&"invalid_reward_choice", "Reward offers require a frozen legal Act and options.")
		return
	var offered: bool = false
	for event: Dictionary in state.rewards.history:
		var details: Dictionary = event.get("details", {})
		if details.get("choice_id") == choice.choice_id and event.get("kind") in ["reward_offered", "relic_offered"]:
			offered = details.get("options") == choice.options and details.get("kind") == String(choice.kind)
	if not offered:
		report.add(&"invalid_saved_offer", "Reward choice must preserve the exact audited offer.")
	var seen: Array[Dictionary] = []
	for option: Dictionary in choice.options:
		if option in seen or not _valid_reward_option(state, content, choice, option):
			report.add(&"invalid_reward_option", "Reward choices must contain distinct valid canonical options.")
		seen.append(option)
	if choice.kind in [&"tile_reward", &"masterwork", &"relic_offer", &"major_reward"] and choice.options.size() > 3:
		report.add(&"invalid_offer_size", "Randomized offers contain at most three distinct choices.")


static func _valid_reward_option(state: RunState, content: ContentRegistry, choice: PendingChoice, option: Dictionary) -> bool:
	var act: int = choice.context["eligibility_act"]
	match choice.kind:
		&"tile_reward", &"masterwork":
			return RunSerializer._has_exact_keys(option, ["definition_id"]) and option["definition_id"] is String \
				and StringName(option["definition_id"]) in RewardRules.tile_pool(content, act, choice.kind == &"masterwork")
		&"relic_offer":
			return RunSerializer._has_exact_keys(option, ["definition_id"]) and option["definition_id"] is String \
				and StringName(option["definition_id"]) in RelicRules.eligible_ids(state, content, act)
		&"major_reward":
			return RunSerializer._has_exact_keys(option, ["major_id"]) and option["major_id"] is String \
				and StringName(option["major_id"]) in RewardRules.major_pool(state, content, act)
		&"training_piece":
			return RunSerializer._has_exact_keys(option, ["piece_id"]) and option["piece_id"] is int \
				and option["piece_id"] in SpecialistRules.trainable_piece_ids(state)
		&"relic_replacement":
			if not choice.context.get("definition_id") is String \
					or StringName(choice.context["definition_id"]) not in RelicRules.eligible_ids(state, content, act):
				return false
			if RunSerializer._has_exact_keys(option, ["decline"]):
				return option["decline"] == true
			return RunSerializer._has_exact_keys(option, ["replace_id"]) and option["replace_id"] is String \
				and RelicRules.removal_validation(state, content, StringName(option["replace_id"])).is_valid
	return false


static func _validate_hand_choice(state: RunState, report: InvariantReport) -> void:
	var choice: PendingChoice = state.pending_choice
	var expected: Array[Dictionary] = []
	if choice.kind == &"compass":
		if state.resolution.stage != &"compass" \
				or not RunSerializer._has_exact_keys(choice.context, ["hand_index", "inspected_ids"]) \
				or not choice.context["hand_index"] is int \
				or not SpecialistSerializer._integers(choice.context["inspected_ids"]):
			report.add(&"invalid_compass_choice", "Compass requires a saved physical inspected set and vacated slot.")
			return
		var slot: int = choice.context["hand_index"]
		if slot < 0 or slot >= state.expansion.hand.size() or state.expansion.hand[slot] != 0 \
				or state.resolution.context.get("hand_index") != slot \
				or choice.context["inspected_ids"] != state.expansion.inspected_ids \
				or state.expansion.inspected_ids.is_empty() or state.expansion.inspected_ids.size() > 3:
			report.add(&"invalid_compass_choice", "Compass inspected copies and empty slot must agree with physical state.")
		for id: int in state.expansion.inspected_ids:
			expected.append({"tile_copy_id": id})
	else:
		if state.resolution.stage != &"reward_queue" \
				or not RunSerializer._has_exact_keys(choice.context, ["eligible_ids", "chosen_removals", "charge_awarded"]) \
				or not SpecialistSerializer._integers(choice.context["eligible_ids"]) \
				or not SpecialistSerializer._integers(choice.context["chosen_removals"]) \
				or choice.context["charge_awarded"] != false:
			report.add(&"invalid_grand_survey_choice", "Grand Survey must preserve remaining original hand copies and pending charge.")
			return
		var seen: Array[int] = []
		for id: int in choice.context["eligible_ids"]:
			if id <= 0 or id in seen or id not in state.expansion.hand:
				report.add(&"invalid_grand_survey_choice", "Only distinct occupied active-hand copies may be selected.")
			seen.append(id)
			expected.append({"tile_copy_id": id, "finish": false})
		if choice.context["chosen_removals"].size() > 1:
			report.add(&"invalid_grand_survey_choice", "Two removals must finish Grand Survey immediately.")
		for id: int in choice.context["chosen_removals"]:
			if id in seen or id not in state.expansion.removed_ids:
				report.add(&"invalid_grand_survey_choice", "Selected Grand Survey copies must remain permanently removed.")
			seen.append(id)
		expected.append({"tile_copy_id": 0, "finish": true})
	if choice.options != expected:
		report.add(&"invalid_hand_relic_options", "Hand Relic choices must match the exact saved physical candidates.")
