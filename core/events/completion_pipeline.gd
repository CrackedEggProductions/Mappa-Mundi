class_name CompletionPipeline
extends RefCounted
## Later subsystems extend these stages; Phase 3 creates no threshold rewards.

const STAGES: Array[StringName] = [
	&"snapshot", &"base_feature_scoring", &"development_effects", &"specialist_effects",
	&"specialist_returns", &"relic_effects", &"relic_milestones",
	&"queue_crossed_track_thresholds", &"resolve_threshold_queue",
]

var _children: Array[FeatureHistoryRecord] = []


func enqueue_child(event: FeatureHistoryRecord) -> void:
	_children.append(event)


func drain_children(state: RunState) -> void:
	# Children enter run history after the entire simultaneous base batch.
	while not _children.is_empty():
		state.features.history.append(_children.pop_front())
