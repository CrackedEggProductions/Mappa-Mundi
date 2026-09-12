class_name ReserveProofService
extends RefCounted

enum Verdict { NOT_PROVABLY_IMPOSSIBLE }


static func assess(_state: RunState, _content: ContentRegistry) -> Verdict:
	# Absence of a placement now is not proof about every remaining alpha action.
	# Expand proof coverage only alongside later Development/Transformation/Relic rules.
	return Verdict.NOT_PROVABLY_IMPOSSIBLE
