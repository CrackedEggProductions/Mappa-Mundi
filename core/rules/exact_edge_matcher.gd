class_name ExactEdgeMatcher
extends RefCounted
## The baseline predicate. Explicit later rule exceptions belong outside it.


static func matches(left: DomainTypes.EdgeType, right: DomainTypes.EdgeType) -> bool:
	return left == right
