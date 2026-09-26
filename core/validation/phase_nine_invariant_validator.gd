class_name PhaseNineInvariantValidator
extends RefCounted
## Validate snapshots at real turn/choice/transition boundaries without resuming.

const STEP_FLAGS: Dictionary = {"advanced": 4, "capacity_refreshed": 5,
	"survey_refreshed": 6, "relics_refreshed": 7, "unlocked": 8, "seeded": 9,
	"shuffled": 10, "information_selected": 11, "counter_reset": 12, "refill_done": 13}
const RESULTS: Array[StringName] = [&"failed", &"fulfilled", &"exceeded"]


static func validate(state: RunState, content: ContentRegistry, report: InvariantReport) -> void:
	if state.charters == null:
		if state.act_transition != null or state.final_result != null \
				or (state.expansion != null and content.get_charter_ids().size() == 9):
			report.add(&"missing_charter_state", "Act transitions and results require Charter state.")
		return
	if state.expansion == null or state.features == null or state.specialists == null \
			or state.trade == null or state.relics == null or state.rewards == null:
		report.add(&"missing_phase_nine_state", "Charters require the complete gameplay profile.")
		return
	_validate_track_total(state, report)
	if not report.is_valid:
		return
	var c: CharterState = state.charters
	var limits: Array[int] = content.get_config().act_placement_limits
	if limits.size() != 3 or state.expansion.current_act not in [1, 2, 3] \
			or c.completed_act_placements.size() != 3:
		report.add(&"invalid_act_counters", "Three-Act state requires three valid placement counters.")
		return
	_validate_journal(state, limits, report)
	_validate_selection(state, content, report)
	if state.act_transition != null:
		_validate_transition(state, limits, report)
	_validate_result(state, content, report)
	_validate_history(state, content, report)
	if report.is_valid:
		_validate_transition_audit(state, report)
	if report.is_valid:
		_validate_evaluations(state, content, report)


static func _validate_track_total(state: RunState, report: InvariantReport) -> void:
	if state.features.tracks == null or state.features.tracks.values.size() != 4:
		report.add(&"invalid_final_score_tracks", "A complete run requires all four cumulative Realm Tracks.")
		return
	var total: int = 0
	for amount: int in state.features.tracks.values:
		if amount < 0 or total > 9223372036854775807 - amount:
			report.add(&"unrepresentable_final_score", "The combined Realm Track total must remain representable throughout the run.")
			return
		total += amount


static func _validate_journal(state: RunState, limits: Array[int], report: InvariantReport) -> void:
	var counts: Array[int] = [0, 0, 0]
	var copies: Array[int] = []
	var previous_act: int = 1
	for entry: Dictionary in state.charters.placement_history:
		if not RunSerializer._has_exact_keys(entry, ["copy_id", "act", "normal_index", "is_bonus"]) \
				or not entry["copy_id"] is int or not entry["act"] is int \
				or not entry["normal_index"] is int or not entry["is_bonus"] is bool:
			report.add(&"invalid_placement_journal", "Physical commit journal must retain typed identity, Act and count.")
			return
		var act: int = entry["act"]
		if act not in [1, 2, 3] or act > state.expansion.current_act or act < previous_act:
			report.add(&"invalid_placement_journal", "Physical commits must remain in chronological Act order.")
			return
		if act > previous_act and counts[previous_act - 1] != limits[previous_act - 1]:
			report.add(&"unfinished_outgoing_act", "A later Act cannot contain placements before its predecessor finishes.")
		previous_act = act
		var copy: TileCopyState = PhysicalTileRules.find_copy(state, entry["copy_id"])
		if copy == null or entry["copy_id"] in copies or copy.definition_id == &"tile.founding.homestead":
			report.add(&"invalid_placement_copy", "Each committed physical tile must be unique and exclude Founding.")
		copies.append(entry["copy_id"])
		if not _matches_physical_commit(state, entry):
			report.add(&"unproven_physical_commit", "Journal identity and timing must match actual board or overlay placement history.")
		if not entry["is_bonus"]:
			counts[act - 1] += 1
		if entry["normal_index"] != counts[act - 1] or counts[act - 1] > limits[act - 1]:
			report.add(&"invalid_normal_placement_history", "Only normal placements advance each Act's sequential count.")
	var counter_act: int = state.expansion.current_act
	if state.act_transition != null and not state.act_transition.counter_reset:
		counter_act = state.act_transition.outgoing_act
	if counter_act not in [1, 2, 3] or state.expansion.normal_placements != counts[counter_act - 1]:
		report.add(&"placement_journal_counter_mismatch", "Current counter must agree with normal physical commits in its Act.")
	for index: int in range(3):
		var completed: int = state.charters.completed_act_placements[index]
		var required: bool = index + 1 < state.expansion.current_act \
			or (state.act_transition != null and index + 1 == state.act_transition.outgoing_act) \
			or state.phase == GamePhase.Type.RUN_COMPLETE
		if completed != (limits[index] if required else 0) or (required and counts[index] != completed):
			report.add(&"invalid_completed_act_history", "Completed Act counters must retain every finished Act exactly once.")
	for job: Dictionary in state.charters.bonus_queue:
		if not RunSerializer._has_exact_keys(job, ["source_id", "act"]) \
				or not job["source_id"] is int or not job["act"] is int \
				or job["source_id"] <= 0 or job["source_id"] >= state.next_runtime_id \
				or job["act"] != state.expansion.current_act:
			report.add(&"invalid_bonus_queue", "Bonus authorizations must retain their source and outgoing Act.")


static func _matches_physical_commit(state: RunState, entry: Dictionary) -> bool:
	for cell: BoardCellState in state.expansion.board.cells.values():
		if cell == null:
			continue
		if cell.base_tile_copy_id == entry["copy_id"]:
			return cell.act_placed == entry["act"] and cell.normal_placement_index == entry["normal_index"]
		for transformation: TransformationState in cell.transformations:
			if transformation != null and transformation.tile_copy_id == entry["copy_id"]:
				return transformation.act_applied == entry["act"] and transformation.placement_index == entry["normal_index"]
	for event: FeatureHistoryRecord in state.features.history:
		if event != null and event.source_id == entry["copy_id"] \
				and event.kind in [&"development_placed", &"development_upgraded"]:
			return event.act == entry["act"] and event.placement_index == entry["normal_index"]
	return false


static func _validate_selection(state: RunState, content: ContentRegistry, report: InvariantReport) -> void:
	var c: CharterState = state.charters
	var first: CharterDefinition = content.get_charter(c.act_one_id)
	if first == null or first.evaluation_act != 1:
		report.add(&"invalid_first_charter", "A run must retain exactly one canonical Act-I Charter.")
	var selected: bool = state.expansion.current_act >= 2
	if state.act_transition != null and state.act_transition.incoming_act == 2 \
			and not state.act_transition.information_selected:
		selected = false
	if selected:
		var second: CharterDefinition = content.get_charter(c.act_two_id)
		var grand: CharterDefinition = content.get_charter(c.grand_id)
		if second == null or second.evaluation_act != 2 or grand == null or grand.evaluation_act != 3 or not c.forecast_visible:
			report.add(&"missing_second_act_information", "Act II onward retains its ordinary Charter and forecasted Grand Charter.")
	elif not c.act_two_id.is_empty() or not c.grand_id.is_empty() or c.forecast_visible:
		report.add(&"premature_charter_information", "Act-II information can only be selected at its transition step.")
	if c.exact_revealed:
		if not selected or c.exact_revealed_act != 2 or c.exact_revealed_index != 11 \
				or PlacementChronology.count_for_act(state, 2) < 11:
			report.add(&"premature_grand_reveal", "Exact requirements reveal only after Act-II placement 11 resolves.")
		if state.expansion.current_act == 2 and state.expansion.normal_placements == 11 \
				and state.resolution != null and state.resolution.context.get("mode", "placement") == "placement" \
				and state.resolution.stage != &"compass":
			report.add(&"grand_reveal_during_consequences", "Placement-11 consequences must finish before exact reveal.")
	elif c.exact_revealed_act != 0 or c.exact_revealed_index != 0 \
			or state.expansion.current_act == 3 \
			or (state.expansion.current_act == 2 and state.phase == GamePhase.Type.TURN_INPUT \
				and state.expansion.normal_placements >= 11):
		report.add(&"missing_grand_reveal", "Exact reveal must persist before the next stable turn after midpoint.")


static func _validate_transition(state: RunState, limits: Array[int], report: InvariantReport) -> void:
	var t: ActTransitionState = state.act_transition
	if t.outgoing_act not in [1, 2] or t.incoming_act != t.outgoing_act + 1 \
			or t.step < 1 or t.step > 14 or t.transition_id <= 0 or t.transition_id >= state.next_runtime_id:
		report.add(&"invalid_act_transition", "Transition requires a stable source and canonical outgoing/incoming Acts.")
		return
	if state.phase not in [GamePhase.Type.RESOLVING_ACT_TRANSITION, GamePhase.Type.PENDING_CHOICE] \
			or state.charters.bonus_active or not state.charters.bonus_queue.is_empty() \
			or state.charters.deferred_refill_index != -1:
		report.add(&"invalid_transition_boundary", "Act transition begins only after the outgoing consequence and bonus queue finishes.")
	for flag: String in STEP_FLAGS:
		if t.get(flag) != (t.step > STEP_FLAGS[flag]):
			report.add(&"invalid_transition_step", "Completed step flags must agree with the exact next operation: " + flag)
	if state.expansion.current_act != (t.incoming_act if t.advanced else t.outgoing_act) \
			or state.expansion.normal_placements != (0 if t.counter_reset else limits[t.outgoing_act - 1]):
		report.add(&"transition_counter_mismatch", "Act advancement and counter reset occur at separate recorded steps.")
	if t.pending_charter_reward_index < 0 or t.pending_charter_reward_index > t.rewards.size() \
			or t.reward_history_start < 0 or t.reward_history_start > state.rewards.history.size() \
			or (t.rewards_queued and (t.step != 2 or t.pending_charter_reward_index >= t.rewards.size())):
		report.add(&"invalid_charter_reward_cursor", "Charter reward continuation must identify the exact pending ordered reward.")
	if t.step > 2 and t.pending_charter_reward_index != t.rewards.size():
		report.add(&"unfinished_charter_rewards", "All outgoing rewards resolve before later transition steps.")
	if t.step > 1 and (t.charter_result.is_empty() or not _valid_progress(t.charter_result)):
		report.add(&"missing_charter_evaluation", "Completed evaluation must persist structured condition progress.")
	if t.step == 1 and (not t.charter_result.is_empty() or not t.rewards.is_empty()):
		report.add(&"premature_charter_evaluation", "Unevaluated transition cannot already contain rewards.")
	for reward: StringName in t.rewards:
		if reward not in [&"tile_reward", &"relic_offer", &"major_reward"]:
			report.add(&"invalid_charter_reward", "Only canonical ordered reward kinds belong to ordinary Charters.")
	if t.pending_hand_refill < -1 or t.pending_hand_refill >= state.expansion.hand.size() \
			or state.expansion.pending_refill_index != (-1 if t.refill_done else t.pending_hand_refill):
		report.add(&"transition_refill_mismatch", "Outgoing final hand refill must remain explicit until the last transition step.")
	var expected_seed_count: int = 10 if t.incoming_act == 2 else 6
	if t.seeded_copy_ids.size() != (expected_seed_count if t.seeded else 0) \
			or not FeatureInvariantValidator._unique_positive(t.seeded_copy_ids):
		report.add(&"invalid_transition_seeding", "Automatic seeding records exactly one set of new physical copies.")
	for id: int in t.seeded_copy_ids:
		var copy: TileCopyState = PhysicalTileRules.find_copy(state, id)
		if copy == null or copy.acquired_act != t.incoming_act:
			report.add(&"invalid_seed_copy", "Seeded identities must resolve in the incoming Act.")


static func _validate_result(state: RunState, content: ContentRegistry, report: InvariantReport) -> void:
	if state.phase != GamePhase.Type.RUN_COMPLETE:
		if state.final_result != null:
			report.add(&"premature_run_result", "An active run cannot already have a final result.")
		return
	var result: RunResult = state.final_result
	if result == null or state.expansion.current_act != 3 or state.act_transition != null \
			or state.pending_choice != null or state.resolution != null or not state.rewards.queue.is_empty() \
			or state.charters.bonus_active or not state.charters.bonus_queue.is_empty() \
			or state.charters.deferred_refill_index != -1 or state.expansion.pending_refill_index != -1:
		report.add(&"invalid_run_complete", "Run end requires a final result and fully exhausted consequence queues.")
		return
	if result.grand_charter_id != state.charters.grand_id or result.grand_charter_result not in RESULTS \
			or result.tracks != state.features.tracks.values or result.tracks.size() != 4:
		report.add(&"invalid_final_result", "Final result must preserve the selected Grand Charter and all final Tracks.")
		return
	var total: int = 0
	for amount: int in result.tracks:
		if amount < 0 or total > 9223372036854775807 - amount:
			report.add(&"invalid_final_score", "Final cumulative Track sum must remain representable.")
			return
		total += amount
	var victories: Dictionary = {&"failed": &"completed_no_victory", &"fulfilled": &"victory", &"exceeded": &"exemplary_victory"}
	if result.score != total or result.victory_result != victories[result.grand_charter_result] \
			or result.statistics.get("run_seed") != state.original_seed:
		report.add(&"invalid_final_score", "Numeric Track sum and victory result are independent canonical values.")
	if result.statistics != ActRules._statistics(state, result):
		report.add(&"invalid_final_statistics", "Final statistics must retain the authoritative records, training, Relics and Charter history.")
	if CharterRules.evaluate(state, content, state.charters.grand_id).overall_state != result.grand_charter_result:
		report.add(&"invalid_final_charter_result", "Recorded victory must agree with the final authoritative civilization.")


static func _valid_progress(data: Dictionary) -> bool:
	if not data.get("charter_id") is String or not data.get("overall_state") is String \
			or StringName(data["overall_state"]) not in RESULTS \
			or not PhaseNineSerializer._array_of(data.get("conditions"), TYPE_DICTIONARY):
		return false
	for condition: Dictionary in data["conditions"]:
		if not condition.get("key") is String or not condition.get("current") is int \
				or not condition.get("target") is int or not condition.get("satisfied") is bool \
				or condition.get("source") not in ["current_state", "history"] \
				or not condition.get("exceed") is bool \
				or not PhaseNineSerializer._array_of(condition.get("witness_ids"), TYPE_INT):
			return false
		if condition["current"] < 0 or condition["target"] < 0 \
				or condition["satisfied"] != (condition["current"] >= condition["target"]):
			return false
	return true


static func _validate_history(state: RunState, content: ContentRegistry, report: InvariantReport) -> void:
	var ids: Array[int] = SpecialistInvariantValidator._occupied_ids(state)
	for piece: SpecialistPieceState in state.specialists.pieces:
		ids.append(piece.piece_id)
	for relic: RelicInstanceState in state.relics.instances:
		ids.append(relic.runtime_id)
	for event: Dictionary in state.relics.history + state.rewards.history:
		if not event.get("event_id") is int:
			report.add(&"invalid_relic_reward_audit", "Relic and reward audit identities must be typed before checking Charter history.")
			return
		ids.append(event["event_id"])
	if state.pending_choice != null:
		ids.append(state.pending_choice.choice_id)
	var selected: Dictionary = {}
	var seeded_acts: Array[int] = []
	for event: Dictionary in state.charters.history:
		if not event.get("event_id") is int or not event.get("kind") is String \
				or not event.get("act") is int or event["act"] < 1 or event["act"] > state.expansion.current_act:
			report.add(&"invalid_charter_history", "Charter audit requires a typed event ID, kind and valid Act.")
			continue
		if event["event_id"] <= 0 or event["event_id"] >= state.next_runtime_id or event["event_id"] in ids:
			report.add(&"charter_history_identity", "Charter audit IDs must remain unique across the run.")
		ids.append(event["event_id"])
		if event["kind"] in ["charter_selected", "grand_charter_selected", "grand_charter_forecast_revealed", "grand_charter_exact_revealed"]:
			if not event.get("charter_id") is String:
				report.add(&"invalid_charter_history", "Selection/reveal identity must be a definition-ID string.")
				continue
			var id: StringName = StringName(event["charter_id"])
			if content.get_charter(id) == null:
				report.add(&"unknown_charter_history", "Selection/reveal audit must identify canonical Charter content.")
			var key: String = "%s:%s" % [event["kind"], id]
			selected[key] = selected.get(key, 0) + 1
		elif event["kind"] == "act_content_seeded":
			var details: Variant = event.get("details")
			if not details is Dictionary or not details.get("act") is int \
					or not PhaseNineSerializer._array_of(details.get("copy_ids"), TYPE_INT):
				report.add(&"invalid_seed_history", "Seeding audit must retain incoming Act and exact physical copies.")
				continue
			var act: int = details["act"]
			if act not in [2, 3] or act != event["act"] or act in seeded_acts \
					or details["copy_ids"].size() != (10 if act == 2 else 6):
				report.add(&"duplicate_seed_history", "Exactly one canonical seed batch may enter each later Act.")
			seeded_acts.append(act)
			_validate_seed_batch(state, details, report)
	for pair: Array in [["charter_selected", state.charters.act_one_id], ["charter_selected", state.charters.act_two_id],
			["grand_charter_selected", state.charters.grand_id], ["grand_charter_forecast_revealed", state.charters.grand_id]]:
		if not String(pair[1]).is_empty() and selected.get("%s:%s" % pair, 0) != 1:
			report.add(&"missing_charter_selection_history", "Selected Charters and forecasts require exactly one persistent audit.")
	var reveal_count: int = selected.get("grand_charter_exact_revealed:%s" % state.charters.grand_id, 0)
	if reveal_count != (1 if state.charters.exact_revealed else 0):
		report.add(&"grand_reveal_history_mismatch", "Exact reveal must agree with its one-time audit.")
	for act: int in [2, 3]:
		var required: bool = state.expansion.current_act >= act
		if state.act_transition != null and state.act_transition.incoming_act == act:
			required = state.act_transition.seeded
		if (act in seeded_acts) != required:
			report.add(&"missing_seed_audit", "Each reached incoming Act must retain exactly its canonical seeded batch.")


static func _validate_seed_batch(state: RunState, data: Dictionary, report: InvariantReport) -> void:
	var act: int = data["act"]
	if act not in [2, 3]:
		return
	var expected: Array[StringName] = ActRules.seed_definitions(act)
	if data.get("definition_ids") != expected:
		report.add(&"invalid_seed_definitions", "Seed batch must preserve the canonical incoming-Act design list.")
	var counts: Dictionary = {}
	var ids: Array[int] = []
	for id: int in data["copy_ids"]:
		var copy: TileCopyState = PhysicalTileRules.find_copy(state, id)
		if copy == null or id in ids or copy.acquired_act != act \
				or copy.acquisition_source != &"act_transition_seed" or copy.definition_id not in expected:
			report.add(&"invalid_seed_identity", "Seed copies require unique identity, canonical design, incoming Act and acquisition source.")
			continue
		ids.append(id)
		counts[copy.definition_id] = counts.get(copy.definition_id, 0) + 1
	for definition: StringName in expected:
		if counts.get(definition, 0) != 2:
			report.add(&"invalid_seed_quantity", "Automatic seeding grants exactly two physical copies per design.")
	for copy: TileCopyState in state.tile_copies:
		if copy != null and copy.acquired_act == act and copy.acquisition_source == &"act_transition_seed" \
				and copy.tile_copy_id not in ids:
			report.add(&"unaudited_seed_copy", "Every transition seed copy must belong to its single recorded batch.")


static func _validate_transition_audit(state: RunState, report: InvariantReport) -> void:
	var starts: Dictionary = {}
	var steps: Dictionary = {}
	var finished: Array[int] = []
	var occupied_ids: Array[int] = SpecialistInvariantValidator._occupied_ids(state)
	for piece: SpecialistPieceState in state.specialists.pieces:
		occupied_ids.append(piece.piece_id)
	for relic: RelicInstanceState in state.relics.instances:
		occupied_ids.append(relic.runtime_id)
	for event: Dictionary in state.charters.history + state.relics.history + state.rewards.history:
		occupied_ids.append(event["event_id"])
	if state.pending_choice != null:
		occupied_ids.append(state.pending_choice.choice_id)
	for event: Dictionary in state.charters.history:
		if event["kind"] not in ["act_transition_started", "act_transition_step", "act_started"]:
			continue
		var details: Variant = event.get("details")
		if not details is Dictionary or not details.get("transition_id") is int:
			report.add(&"invalid_transition_audit", "Transition audit requires its stable transition identity.")
			return
		var id: int = details["transition_id"]
		if event["kind"] == "act_transition_started":
			if id <= 0 or id >= event["event_id"] or starts.has(id) or id in occupied_ids \
					or not details.get("outgoing_act") is int or not details.get("incoming_act") is int \
					or details["outgoing_act"] not in [1, 2] \
					or details.get("incoming_act") != details["outgoing_act"] + 1:
				report.add(&"invalid_transition_start", "Each transition starts once with consecutive outgoing/incoming Acts.")
				return
			starts[id] = details
			steps[id] = 0
		elif not starts.has(id):
			report.add(&"unstarted_transition", "Transition steps must follow their recorded start.")
			return
		elif event["kind"] == "act_transition_step":
			var step: Variant = details.get("step")
			if not step is int or step != steps[id] + 1 or step > 14 \
					or details.get("step_key") != String(ActRules.STEP_KEYS[step - 1]) \
					or details.get("outgoing_act") != starts[id]["outgoing_act"] \
					or details.get("incoming_act") != starts[id]["incoming_act"]:
				report.add(&"invalid_transition_step_audit", "Canonical transition operations occur exactly once in listed order.")
				return
			steps[id] = step
		elif steps[id] != 14 or id in finished or event["act"] != starts[id]["incoming_act"]:
			report.add(&"premature_act_started", "Incoming turn input follows all fourteen transition steps exactly once.")
		else:
			finished.append(id)
	for id: int in starts:
		if state.act_transition != null and state.act_transition.transition_id == id:
			if steps[id] != state.act_transition.step - 1 or id in finished:
				report.add(&"transition_cursor_audit_mismatch", "Saved next step must follow the exact completed transition audit.")
		elif id not in finished:
			report.add(&"orphan_transition_audit", "An unfinished transition must retain its resumable state.")
	if state.act_transition != null and not starts.has(state.act_transition.transition_id):
		report.add(&"missing_transition_audit", "Current transition must retain its start event.")


static func validate_hand_boundary(state: RunState, report: InvariantReport) -> void:
	var expansion: ExpansionState = state.expansion
	var c: CharterState = state.charters
	var expected_empty: Array[int] = []
	for index: int in [expansion.pending_refill_index, c.deferred_refill_index]:
		if index < -1 or index >= expansion.hand.size() or (index >= 0 and index in expected_empty):
			report.add(&"invalid_phase_nine_refill", "Pending ordinary and bonus refills must identify distinct valid slots.")
		elif index >= 0:
			expected_empty.append(index)
	if state.phase == GamePhase.Type.PENDING_CHOICE and state.pending_choice != null and state.pending_choice.kind == &"compass":
		ExpansionInvariantValidator._validate_compass(state, report)
		return
	if not expansion.inspected_ids.is_empty():
		report.add(&"stranded_inspected_tiles", "Inspected copies require their Compass choice.")
	var actual_empty: Array[int] = []
	for index: int in range(expansion.hand.size()):
		if expansion.hand[index] == 0:
			actual_empty.append(index)
	expected_empty.sort()
	if state.phase == GamePhase.Type.RUN_COMPLETE:
		if not expected_empty.is_empty() or actual_empty.size() > 1:
			report.add(&"invalid_final_hand", "Final Act skips exactly its optional ordinary replacement draw.")
	elif actual_empty != expected_empty:
		report.add(&"untracked_phase_nine_refill", "Every empty active-hand slot must retain its exact continuation.")
	if state.phase == GamePhase.Type.TURN_INPUT and (not expected_empty.is_empty() or c.bonus_active \
			or not c.bonus_queue.is_empty() or state.resolution != null or state.pending_choice != null):
		report.add(&"invalid_phase_nine_turn", "Normal input requires all previous consequences and refills complete.")
	if state.phase == GamePhase.Type.RESOLVING_ACT_TRANSITION and state.act_transition == null:
		report.add(&"missing_act_transition", "A transition phase must identify its exact resumable step.")
	if state.phase == GamePhase.Type.BONUS_INPUT and (c.bonus_queue.is_empty() or c.bonus_active \
			or expansion.pending_refill_index != -1 or state.act_transition != null):
		report.add(&"invalid_bonus_input", "Bonus input requires one authorized outgoing-Act placement and no active transition.")
	if c.bonus_active and (state.phase != GamePhase.Type.PENDING_CHOICE or state.resolution == null \
			or c.placement_history.is_empty() or not c.placement_history.back().get("is_bonus", false)):
		report.add(&"invalid_active_bonus", "An active bonus continuation must belong to the last committed bonus placement.")


static func _validate_evaluations(state: RunState, content: ContentRegistry, report: InvariantReport) -> void:
	var acts: Array[int] = []
	for evaluation: Dictionary in state.charters.evaluations:
		if not _valid_progress(evaluation) or not evaluation.get("evaluation_act") is int \
				or evaluation["evaluation_act"] not in [1, 2, 3]:
			report.add(&"invalid_charter_evaluation", "Evaluation history requires typed canonical condition progress and Act.")
			continue
		var act: int = evaluation["evaluation_act"]
		var id: StringName = [state.charters.act_one_id, state.charters.act_two_id, state.charters.grand_id][act - 1]
		var definition: CharterDefinition = content.get_charter(id)
		if act in acts or StringName(evaluation["charter_id"]) != id or definition == null:
			report.add(&"duplicate_charter_evaluation", "Each selected Act objective evaluates exactly once.")
			continue
		acts.append(act)
		var canonical: Dictionary = CharterRules.evaluate(state, content, id).to_dict()
		if evaluation["conditions"].size() != canonical["conditions"].size():
			report.add(&"invalid_charter_conditions", "Historical progress must retain every canonical condition.")
			continue
		var fulfilled: bool = true
		var exceeded: bool = true
		for index: int in range(evaluation["conditions"].size()):
			var condition: Dictionary = evaluation["conditions"][index]
			for key: String in ["key", "target", "source", "exceed"]:
				if condition[key] != canonical["conditions"][index][key]:
					report.add(&"invalid_charter_conditions", "Evaluation metadata must match the selected canonical objective.")
			if condition["exceed"]:
				exceeded = exceeded and condition["satisfied"]
			else:
				fulfilled = fulfilled and condition["satisfied"]
		var expected: String = "failed" if not fulfilled else ("exceeded" if exceeded else "fulfilled")
		if evaluation["overall_state"] != expected \
				or evaluation.get("rewards_generated") != CharterRules.ordered_rewards(definition, StringName(expected)) \
				or not PhaseNineSerializer._array_of(evaluation.get("rewards_resolved"), TYPE_DICTIONARY):
			report.add(&"invalid_evaluation_result", "Exceed requires fulfillment and exactly its canonical ordered rewards.")
	for act: int in [1, 2, 3]:
		var required: bool = act < state.expansion.current_act or state.phase == GamePhase.Type.RUN_COMPLETE
		if state.act_transition != null and state.act_transition.outgoing_act == act:
			required = state.act_transition.step > 1
		if (act in acts) != required:
			report.add(&"missing_charter_evaluation", "Every outgoing evaluated Act must retain exactly its structured result.")
