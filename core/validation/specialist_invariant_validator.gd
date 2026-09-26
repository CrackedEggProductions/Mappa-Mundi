class_name SpecialistInvariantValidator
extends RefCounted
## Validate stored identity and choices without assigning, returning, training or RNG.


static func validate(state: RunState, content: ContentRegistry, report: InvariantReport) -> void:
	if state.specialists == null:
		if state.pending_choice != null or state.resolution != null or state.phase == GamePhase.Type.PENDING_CHOICE:
			report.add(&"missing_specialist_state", "A Specialist continuation requires its physical roster.")
		return
	if state.features == null or state.expansion == null:
		report.add(&"specialists_without_features", "Specialist state requires initialized board/feature state.")
		return
	if state.specialists.pieces.size() < 2 or state.specialists.pieces.size() > 3:
		report.add(&"specialist_cap", "Alpha roster must contain two or three persistent generic/trained pieces.")
	var ids: Array[int] = _occupied_ids(state)
	var occupied: Dictionary = {}
	for piece: SpecialistPieceState in state.specialists.pieces:
		if piece == null:
			report.add(&"missing_specialist_piece", "Roster cannot contain a null physical piece.")
			continue
		_check_id(state, piece.piece_id, ids, report)
		if piece.status not in SpecialistPieceState.Status.values():
			report.add(&"invalid_specialist_status", "Unknown piece status.", piece.piece_id)
		if not piece.role_definition_id.is_empty() and content.get_specialist(piece.role_definition_id) == null:
			report.add(&"unknown_specialist_role", "Trained role must resolve in this canonical alpha pool.", piece.piece_id)
		_validate_training_history(state, piece, report)
		if piece.status == SpecialistPieceState.Status.AVAILABLE:
			if piece.assigned_target_type != -1 or piece.assigned_target_id != 0 \
					or piece.assigned_act != 0 or piece.assigned_placement_index != 0 \
					or not piece.growth_baseline_component_ids.is_empty() or not piece.qualifying_component_ids.is_empty():
				report.add(&"stale_specialist_assignment", "Available pieces must not retain an active assignment.", piece.piece_id)
			continue
		_validate_assignment(state, piece, report)
		var target: String = "%d:%d" % [piece.assigned_target_type, piece.assigned_target_id]
		if occupied.has(target):
			report.add(&"duplicate_specialist_occupancy", "One connected feature may hold only one piece.", piece.piece_id)
		occupied[target] = true
	_validate_history(state, report)
	_validate_resolution(state, report)
	_validate_choice(state, ids, report)


static func _validate_assignment(state: RunState, piece: SpecialistPieceState, report: InvariantReport) -> void:
	if piece.assigned_act < 1 or piece.assigned_act > state.expansion.current_act \
			or piece.assigned_placement_index < 0 or piece.assigned_placement_index > PlacementChronology.count_for_act(state, piece.assigned_act) \
			or piece.assigned_target_type not in [0, 1, 2, 3, 4]:
		report.add(&"invalid_specialist_assignment", "Assignment timing/type is outside current run context.", piece.piece_id)
		return
	if piece.assigned_target_type == 4:
		var found: bool = false
		for enclosure: EnclosureState in state.features.enclosures:
			if enclosure.enclosure_id == piece.assigned_target_id:
				found = true
				if enclosure.stage in enclosure.completed_stages:
					report.add(&"completed_specialist_target", "Completed enclosure must return its Steward.", piece.piece_id)
		if not found or not piece.role_definition_id.is_empty():
			report.add(&"invalid_specialist_enclosure", "Only a generic Steward may occupy a persistent enclosure.", piece.piece_id)
	else:
		var lineage: FeatureLineageState = state.features.lineage(piece.assigned_target_id)
		if lineage == null or not lineage.active or lineage.feature_type != piece.assigned_target_type:
			report.add(&"unresolved_specialist_target", "Assignment must follow its current descendant lineage.", piece.piece_id)
		elif lineage.completed:
			report.add(&"completed_specialist_target", "Recorded completed feature cannot retain an assignment.", piece.piece_id)
		if not piece.role_definition_id.is_empty() \
				and SpecialistContentValidator.ROLES.get(piece.role_definition_id, -1) != piece.assigned_target_type:
			report.add(&"ineligible_specialist_target", "Role cannot occupy this feature type.", piece.piece_id)
	_validate_growth(state, piece, report)
	if piece.role_definition_id == &"specialist.harbormaster" and not SpecialistRules.role_eligible(
		state, piece.role_definition_id, piece.assigned_target_type, piece.assigned_target_id, TopologyService.rebuild(state)):
		report.add(&"ineligible_harbormaster", "Harbormaster requires current River/Settlement contact.", piece.piece_id)


static func _validate_growth(state: RunState, piece: SpecialistPieceState, report: InvariantReport) -> void:
	for values: Array[int] in [piece.growth_baseline_component_ids, piece.qualifying_component_ids]:
		if not FeatureInvariantValidator._unique_positive(values):
			report.add(&"invalid_specialist_growth", "Growth identity sets require unique positive components.", piece.piece_id)
		for id: int in values:
			if state.features.component(id) == null:
				report.add(&"unresolved_specialist_growth", "Observed growth identity must resolve to a persistent component.", piece.piece_id)
	for id: int in piece.qualifying_component_ids:
		var component: FeatureComponentState = state.features.component(id)
		if component != null and (component.feature_type != piece.assigned_target_type \
				or component.lineage_id != piece.assigned_target_id):
			report.add(&"unowned_specialist_growth", "Qualifying new growth must belong to the assigned feature.", piece.piece_id)


static func _validate_choice(state: RunState, ids: Array[int], report: InvariantReport) -> void:
	var choice: PendingChoice = state.pending_choice
	if choice == null:
		if state.phase == GamePhase.Type.PENDING_CHOICE:
			report.add(&"missing_pending_choice", "Pending phase requires an authoritative choice.")
		return
	_check_id(state, choice.choice_id, ids, report)
	if state.phase != GamePhase.Type.PENDING_CHOICE:
		report.add(&"invalid_choice_phase", "Stored player choice requires PENDING_CHOICE phase.")
	if state.relics != null and choice.kind not in [&"specialist_assignment", &"specialist_training"]:
		return # PhaseEightInvariantValidator owns these typed choices.
	if choice.kind not in [&"specialist_assignment", &"specialist_training"] or choice.options.is_empty():
		report.add(&"invalid_specialist_choice", "Choice requires a supported kind and persisted options.")
		return
	var seen: Array[String] = []
	for option: Dictionary in choice.options:
		var signature: String = JSON.stringify(option, "", true)
		if signature in seen:
			report.add(&"duplicate_specialist_option", "Persisted choice options must be distinct.")
		seen.append(signature)
		if choice.kind == &"specialist_training":
			if not option.get("role_definition_id") is String or StringName(option["role_definition_id"]) not in SpecialistContentValidator.ROLES:
				report.add(&"invalid_training_option", "Training offer must contain canonical alpha role IDs.")
				return
		else:
			_validate_assignment_option(state, option, report)
	if choice.kind == &"specialist_training":
		if not RunSerializer._has_exact_keys(choice.context, ["piece_id", "status", "assigned_target_type", "assigned_target_id", "resume_phase"]):
			report.add(&"invalid_training_context", "Training context must preserve piece occupation and resume phase.")
			return
		for key: String in choice.context:
			if not choice.context[key] is int:
				report.add(&"invalid_training_context", "Training context IDs/status must be integers.")
				return
		var piece: SpecialistPieceState = state.specialists.piece(int(choice.context.get("piece_id", 0)))
		if piece == null or not piece.role_definition_id.is_empty() or choice.options.size() > 3:
			report.add(&"invalid_training_target", "Training requires one generic piece and at most three roles.")
		elif piece.status == SpecialistPieceState.Status.ASSIGNED:
			for option: Dictionary in choice.options:
				if SpecialistContentValidator.ROLES.get(StringName(option.get("role_definition_id", "")), -1) != piece.assigned_target_type:
					report.add(&"ineligible_training_option", "Committed training must preserve legal occupation.")
		if piece != null:
			var pool: Array[StringName] = SpecialistRules.training_pool(state, piece)
			if choice.options.size() != mini(3, pool.size()) or choice.context["status"] != piece.status \
					or choice.context["assigned_target_type"] != piece.assigned_target_type \
					or choice.context["assigned_target_id"] != piece.assigned_target_id \
					or (choice.context["resume_phase"] != GamePhase.Type.TURN_INPUT and not (state.rewards != null and state.resolution != null and state.resolution.stage == &"reward_queue" and choice.context["resume_phase"] == GamePhase.Type.RESOLVING_PLACEMENT)):
				report.add(&"stale_training_context", "Training offer must preserve legal pool size and original occupation.")
			for option: Dictionary in choice.options:
				if StringName(option.get("role_definition_id", "")) not in pool:
					report.add(&"ineligible_training_option", "Offered role fails current role eligibility.")
	elif state.resolution == null:
		report.add(&"missing_assignment_continuation", "Assignment choice must preserve committed placement continuation.")
	else:
		if not RunSerializer._has_exact_keys(choice.context, ["affected_targets", "decline_allowed"]) \
				or choice.context["decline_allowed"] != true \
				or choice.context["affected_targets"] != state.resolution.affected_targets:
			report.add(&"invalid_assignment_context", "Assignment context must preserve exact local targets and decline.")
		if report.is_valid and choice.options != SpecialistRules.assignment_options(state, state.resolution.affected_targets):
			report.add(&"stale_assignment_options", "Persisted choices must equal authoritative legal piece/target combinations.")


static func _validate_assignment_option(state: RunState, option: Dictionary, report: InvariantReport) -> void:
	if not RunSerializer._has_exact_keys(option, ["piece_id", "target_type", "target_id"]) \
			or not option["piece_id"] is int or not option["target_type"] is int or not option["target_id"] is int:
		report.add(&"invalid_assignment_option", "Assignment option must retain exact piece and target IDs.")
		return
	var piece: SpecialistPieceState = state.specialists.piece(option["piece_id"])
	if piece == null or piece.status != SpecialistPieceState.Status.AVAILABLE:
		report.add(&"unavailable_assignment_piece", "Choice cannot deploy an absent or assigned piece.")
		return
	var target_type: int = option["target_type"]
	var target_id: int = option["target_id"]
	if target_type == 4:
		var found: bool = false
		for enclosure: EnclosureState in state.features.enclosures:
			if enclosure.enclosure_id == target_id:
				found = enclosure.stage in [&"monastery", &"abbey"] and enclosure.stage not in enclosure.completed_stages
		if not found or not piece.role_definition_id.is_empty():
			report.add(&"invalid_assignment_enclosure", "Only an unfinished Monastery-family enclosure permits a new generic assignment.")
	else:
		var lineage: FeatureLineageState = state.features.lineage(target_id)
		if target_type not in [0, 1, 2, 3] or lineage == null or not lineage.active \
				or lineage.completed or lineage.feature_type != target_type:
			report.add(&"invalid_assignment_target", "Choice requires a current unfinished matching feature.")
		if not piece.role_definition_id.is_empty() \
				and SpecialistContentValidator.ROLES.get(piece.role_definition_id, -1) != target_type:
			report.add(&"ineligible_assignment_role", "Piece role is incompatible with offered target.")
	for assigned: SpecialistPieceState in state.specialists.pieces:
		if assigned != null and assigned.status == SpecialistPieceState.Status.ASSIGNED \
				and assigned.assigned_target_type == target_type and assigned.assigned_target_id == target_id:
			report.add(&"occupied_assignment_target", "Choice cannot offer an already occupied feature.")
	if state.resolution != null:
		var target: Dictionary = {"target_type": target_type, "target_id": target_id}
		if target not in state.resolution.affected_targets:
			report.add(&"nonlocal_assignment_target", "Assignment choice must be within the committed action's affected targets.")


static func _validate_resolution(state: RunState, report: InvariantReport) -> void:
	if state.resolution == null:
		return
	var resolution: ResolutionState = state.resolution
	if state.relics != null and resolution.stage != &"specialist_assignment":
		return # Phase-8 continuation stages validate against recorded, already-applied facts.
	if resolution.source_id <= 0 or resolution.stage != &"specialist_assignment" \
			or resolution.source_id >= state.next_runtime_id:
		report.add(&"invalid_specialist_resolution", "Committed continuation requires a source and stage.")
	if state.pending_choice == null or state.pending_choice.kind != &"specialist_assignment":
		report.add(&"orphan_specialist_resolution", "Stable placement continuation must await its assignment choice.")
	for target: Dictionary in resolution.affected_targets:
		if not RunSerializer._has_exact_keys(target, ["target_type", "target_id"]) \
				or not target["target_type"] is int or not target["target_id"] is int:
			report.add(&"invalid_affected_target", "Continuation affected targets must retain typed IDs.")
	if report.is_valid:
		var expected_targets: Array[Dictionary] = SpecialistPlacementService.committed_targets(state, resolution.source_id)
		if expected_targets.is_empty() or resolution.affected_targets != expected_targets:
			report.add(&"invalid_committed_locality", "Saved affected targets must match the most recent physical placement.")
		var expected: Dictionary = FeatureScoringService.capture(state, TopologyService.rebuild(state), resolution.source_id).data()
		if resolution.completion_snapshot != expected:
			report.add(&"invalid_completion_continuation", "Saved immutable snapshot must match the committed pre-effect board.")
		var source_found: bool = false
		for tile: TileCopyState in state.tile_copies:
			if tile.tile_copy_id == resolution.source_id:
				source_found = true
		if not source_found:
			report.add(&"missing_resolution_source", "Continuation source must be a physical placed tile.")
		var placed_development: DevelopmentState = DevelopmentService.find(state, resolution.source_id)
		if placed_development != null or resolution.immediate_development_copy_id != 0:
			if placed_development == null or resolution.immediate_development_copy_id != resolution.source_id:
				report.add(&"invalid_immediate_development", "Immediate effect continuation must identify its placed Development.")
			var event_found: bool = false
			for event: FeatureHistoryRecord in state.features.history:
				if event.event_id == resolution.immediate_parent_event_id \
						and event.kind in [&"development_placed", &"development_upgraded"] \
						and event.source_id == resolution.source_id \
						and event.placement_index == state.expansion.normal_placements:
					event_found = true
			if not event_found:
				report.add(&"invalid_immediate_parent", "Immediate effect requires its placement history event.")
		elif resolution.immediate_parent_event_id != 0:
			report.add(&"orphan_immediate_parent", "Ordinary placement cannot retain a Development effect parent.")


static func _check_id(state: RunState, id: int, ids: Array[int], report: InvariantReport) -> void:
	if id <= 0 or id in ids or id >= state.next_runtime_id:
		report.add(&"specialist_id_collision", "Piece/choice IDs must be unique and precede allocation cursor.", id)
	ids.append(id)


static func _occupied_ids(state: RunState) -> Array[int]:
	var ids: Array[int] = []
	for tile: TileCopyState in state.tile_copies:
		ids.append(tile.tile_copy_id)
	for component: FeatureComponentState in state.features.components:
		ids.append(component.component_id)
	for lineage: FeatureLineageState in state.features.lineages:
		ids.append(lineage.lineage_id)
	for enclosure: EnclosureState in state.features.enclosures:
		ids.append(enclosure.enclosure_id)
	for event: FeatureHistoryRecord in state.features.history:
		ids.append(event.event_id)
	if state.trade != null:
		for lineage: TradeNetworkLineageState in state.trade.lineages:
			ids.append(lineage.lineage_id)
		for event: TradeHistoryRecord in state.trade.history:
			ids.append(event.event_id)
	return ids


static func _validate_training_history(state: RunState, piece: SpecialistPieceState, report: InvariantReport) -> void:
	if piece.role_definition_id.is_empty():
		if not piece.training_history.is_empty():
			report.add(&"generic_training_history", "A trained piece can never return to generic status.", piece.piece_id)
		return
	if piece.training_history.size() != 1:
		report.add(&"invalid_training_history", "Permanent role conversion must have exactly one training record.", piece.piece_id)
		return
	var record: Dictionary = piece.training_history[0]
	if not RunSerializer._has_exact_keys(record, ["event_id", "role_definition_id", "act", "placement_index"]) \
			or not record["event_id"] is int or not record["role_definition_id"] is String \
			or not record["act"] is int or not record["placement_index"] is int:
		report.add(&"invalid_training_history", "Training record requires typed persistent identity and timing.", piece.piece_id)
		return
	if StringName(record["role_definition_id"]) != piece.role_definition_id \
			or record["act"] < 1 or record["act"] > state.expansion.current_act \
			or record["placement_index"] < 0 or record["placement_index"] > PlacementChronology.count_for_act(state, record["act"]):
		report.add(&"invalid_training_history", "Role and training timing must agree with authoritative piece.", piece.piece_id)
	var found: bool = false
	for event: Dictionary in state.specialists.history:
		if event.get("event_id") == record["event_id"] and event.get("kind") == "specialist_trained" \
				and event.get("piece_id") == piece.piece_id \
				and event.get("role_definition_id") == record["role_definition_id"]:
			found = true
	if not found:
		report.add(&"missing_training_event", "Piece training history must reference its structured training event.", piece.piece_id)


static func _validate_history(state: RunState, report: InvariantReport) -> void:
	const KINDS: Array[String] = ["specialist_assigned", "specialist_trained", "specialist_triggered",
		"specialist_returned", "steward_recruited", "training_reward_deferred"]
	var seen: Array[int] = []
	for record: Dictionary in state.specialists.history:
		if not record.get("event_id") is int or not record.get("kind") is String \
				or not record.get("piece_id") is int or not record.get("act") is int \
				or not record.get("placement_index") is int:
			report.add(&"invalid_specialist_history", "Specialist audit requires typed event, kind, piece and timing.")
			continue
		var id: int = record["event_id"]
		if id in seen or record["kind"] not in KINDS:
			report.add(&"invalid_specialist_history", "Specialist events require unique known records.", id)
		seen.append(id)
		if (record["kind"] == "training_reward_deferred" and record["piece_id"] != 0) \
				or (record["kind"] != "training_reward_deferred" and state.specialists.piece(record["piece_id"]) == null):
			report.add(&"unresolved_specialist_history", "Specialist event piece must resolve.", id)
		var found: bool = false
		for event: FeatureHistoryRecord in state.features.history:
			if event.event_id == id and String(event.kind) == record["kind"] \
					and event.source_id == record["piece_id"] and event.act == record["act"] \
					and event.placement_index == record["placement_index"]:
				found = true
		if not found:
			report.add(&"unresolved_specialist_history", "Specialist audit must reference its structured feature event.", id)
	var reward_ids: Array[int] = []
	for reward: Dictionary in state.specialists.deferred_rewards:
		if not RunSerializer._has_exact_keys(reward, ["event_id", "reward_kind", "quantity"]) \
				or not reward["event_id"] is int or reward["reward_kind"] != "normal_tile_reward" \
				or not reward["quantity"] is int or reward["quantity"] != 1:
			report.add(&"invalid_training_fallback", "Training fallback must retain one typed normal Tile Reward handoff.")
			continue
		if reward["event_id"] in reward_ids:
			report.add(&"duplicate_training_fallback", "One fallback event cannot create duplicate reward handoffs.")
		reward_ids.append(reward["event_id"])
		var found: bool = false
		for record: Dictionary in state.specialists.history:
			if record.get("event_id") == reward["event_id"] and record.get("kind") == "training_reward_deferred":
				found = true
		if not found:
			report.add(&"unresolved_training_fallback", "Deferred reward must reference its training fallback event.")
