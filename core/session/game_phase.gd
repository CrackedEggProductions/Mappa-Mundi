class_name GamePhase
extends RefCounted
## Explicit phase vocabulary; RulesEngine owns implemented turn transitions.

enum Type {
	SETUP = 0,
	TURN_INPUT = 1,
	RESOLVING_PLACEMENT = 2,
	RESOLVING_ACT_TRANSITION = 3,
	PENDING_CHOICE = 4,
	RUN_COMPLETE = 5,
	BONUS_INPUT = 6,
}
