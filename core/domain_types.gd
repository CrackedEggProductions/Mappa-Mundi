class_name DomainTypes
extends RefCounted
## Finite alpha vocabulary. Enum values are explicit; do not reorder for saves.

enum EdgeType { FIELD = 0, FOREST = 1, RIVER = 2, ROAD = 3, SETTLEMENT = 4 }
## Field is support geography; Monastery/Abbey is a separate enclosure.
enum FeatureType { ROAD = 0, SETTLEMENT = 1, FOREST = 2, RIVER = 3 }
enum TileClass { EXPANSION = 0, DEVELOPMENT = 1, UPGRADE = 2, TRANSFORMATION = 3 }
enum PlacementMode { EXPANSION = 0, DEVELOPMENT = 1, UPGRADE = 2, TRANSFORMATION = 3 }
## Order also defines the canonical threshold queue order.
enum TrackType { POPULATION = 0, TRADE = 1, CULTURE = 2, ECOLOGY = 3 }
enum RewardClass {
	NONE = 0,
	BASIC_EXPANSION = 1,
	SPECIALIZED_EXPANSION = 2,
	ORDINARY_DEVELOPMENT = 3,
	MAJOR_RARE = 4,
}
enum ChoiceType {
	SPECIALIST_ASSIGNMENT = 0,
	SPECIALIST_TRAINING = 1,
	COMPASS_REPLACEMENT = 2,
	TILE_REWARD = 3,
	RELIC_OFFER = 4,
	RELIC_REPLACEMENT = 5,
	MAJOR_REWARD = 6,
	STEWARD_RELAY = 7,
}
enum EventType {
	TILE_PLACED = 0,
	DEVELOPMENT_PLACED = 1,
	TRANSFORMATION_APPLIED = 2,
	FEATURE_MERGED = 3,
	FEATURE_REOPENED = 4,
	FEATURE_COMPLETED = 5,
	SPECIALIST_RETURNED = 6,
	RELIC_TRIGGERED = 7,
	MILESTONE_EARNED = 8,
	TRACK_THRESHOLD_CROSSED = 9,
	REWARD_RESOLVED = 10,
	BONUS_PLACEMENT_GRANTED = 11,
	ACT_TRANSITION_STARTED = 12,
	ACT_STARTED = 13,
	RUN_ENDED = 14,
}
## Categories only. Run-owned allocation and persistent entities begin in Phase 1.
enum EntityKind {
	TILE_COPY = 0,
	FEATURE_COMPONENT = 1,
	FEATURE_LINEAGE = 2,
	TRADE_NETWORK_LINEAGE = 3,
	DEVELOPMENT = 4,
	TRANSFORMATION = 5,
	SPECIALIST_PIECE = 6,
	ENCLOSURE = 7,
	HISTORY_EVENT = 8,
}
