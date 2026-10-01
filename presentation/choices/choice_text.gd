class_name ChoiceText
extends RefCounted
## Presentation wording only. The canonical services still calculate every effect.

const DESCRIPTIONS: Dictionary = {
	&"": "On completion: Road +2 Trade; Settlement +2 Population; Forest +2 Ecology; Monastery-family enclosure +2 Culture. Rivers are environment, not assignment targets. Then returns.",
	&"specialist.merchant": "Road. On completion, +2 Trade per distinct Settlement beyond the first in its full Trade Network.",
	&"specialist.cartographer": "Road. On completion, +1 Trade per genuinely new Road tile added after assignment. Absorbed old tiles do not count; training in place starts growth credit at training.",
	&"specialist.architect": "Settlement. On completion, +2 Culture per distinct Development family. Upgrades count as their base family.",
	&"specialist.homesteader": "Settlement. On completion, +1 Population per distinct touching Field tile, in addition to base support.",
	&"specialist.naturalist": "Forest. On completion, +1 Ecology per Forest tile if no ordinary Development disqualifies it. Forester’s Lodge is allowed.",
	&"specialist.forester": "Forest. On completion, +1 Ecology per genuinely new Forest tile after assignment. Absorbed old tiles do not count; training in place starts growth credit at training.",
	&"specialist.riverkeeper": "Forest touching River. On Forest completion, +1 Ecology per distinct current River tile contact, in addition to base contact scoring.",
	&"specialist.harbormaster": "Settlement touching River. On Settlement completion, +2 Trade per distinct Settlement touching the same connected River system, including its host, plus +1 for each of those with a Port.",
	&"relic.boundary_stones": "Once per Act, an Expansion may ignore exactly one Field/Forest mismatch. That edge remains a hard boundary. All other edges must match.",
	&"relic.surveyors_compass": "On the first normal Survey of the Act, inspect up to three next bag tiles and choose a replacement. Return the others and shuffle. Grand Survey does not trigger this.",
	&"relic.wayfarers_satchel": "Gain a second Reserve slot. Cannot be replaced while the extra slot would strand a tile.",
	&"relic.village_green": "When a Settlement completes and its exterior touches Field, Forest or River, gain Culture equal to its full current size.",
	&"relic.ferry_rights": "Trade Networks reaching a Settlement by Road also link Settlements touching the same connected River. Links propagate through attached Roads; physical Road size is unchanged.",
	&"relic.mixed_use_charter": "A Settlement tile may host Housing family and Market family together. No other pair is allowed. Cannot be removed while this coexistence depends on it.",
	&"relic.historic_routes": "In Acts II and III, a completed Road grants +1 Culture per Act I Road component it currently contains.",
	&"relic.stewards_relay": "A returned Steward or Specialist may immediately move to an eligible unfinished feature touching the completed feature, or decline.",
	&"relic.one_great_city": "Only the currently largest Settlements (including ties) earn base Population; double their newly scoring base payout. Smaller Settlements still resolve non-base effects.",
	&"relic.the_long_road": "Roads at least as long as the prior Longest Road record double newly scoring base Trade. Shorter Roads earn no base Trade; other effects still resolve.",
	&"recruit_steward": "Gain one available generic Steward, up to the three-piece cap.",
	&"masterwork": "Choose an offered Specialized/Hybrid, Upgrade or Major/Rare design. Add three copies and shuffle the bag.",
	&"relic_cache": "Resolve a normal Relic offer, then receive one Normal Tile Reward.",
	&"grand_survey": "Permanently remove up to two occupied active-hand tiles, replacing them one at a time. Gain one Survey charge this Act. Does not spend a charge or trigger Compass.",
}


static func description(id: StringName) -> String:
	return String(DESCRIPTIONS.get(id, ""))


static func tile_help(tile: TileDefinition) -> String:
	# Draft cards keep one short sentence; hover exposes the complete content reminder.
	if not tile.effect_summary.is_empty():
		return tile.effect_summary.get_slice(". ", 0).trim_suffix(".") + "."
	return tile_edges(tile)


static func tile_category(tile: TileDefinition) -> String:
	if tile.intersection_hub:
		return "Intersection"
	match tile.tile_class:
		DomainTypes.TileClass.DEVELOPMENT:
			return "Development"
		DomainTypes.TileClass.UPGRADE:
			return "Upgrade — " + String(tile.upgrade_from_definition_id).get_slice(".", 2).replace("_", " ").capitalize()
		DomainTypes.TileClass.TRANSFORMATION:
			return "Transformation"
	return "Specialized / Hybrid Expansion" if tile.reward_class == DomainTypes.RewardClass.SPECIALIZED_EXPANSION else "Basic Expansion"


static func tile_tooltip(tile: TileDefinition) -> String:
	var text: String = tile.display_name + "\n" + tile_category(tile)
	if tile.tile_class == DomainTypes.TileClass.EXPANSION:
		text += "\n" + tile_edges(tile)
	if not tile.placement_summary.is_empty():
		text += "\n\nPlacement:\n" + tile.placement_summary
	if not tile.effect_summary.is_empty():
		text += "\n\nEffect:\n" + tile.effect_summary
	return text


static func tile_edges(tile: TileDefinition) -> String:
	const EDGES: Array[String] = ["Field", "Forest", "River", "Road", "Settlement"]
	var parts: Array[String] = []
	for edge: int in range(EDGES.size()):
		var count: int = tile.canonical_edges.count(edge)
		if count > 0:
			parts.append("%s ×%d" % [EDGES[edge], count])
	return "Edges: " + " · ".join(parts)


static func role_name(state: RunState, content: ContentRegistry, piece_id: int) -> String:
	if state.specialists == null:
		return "Steward"
	var piece: SpecialistPieceState = state.specialists.piece(piece_id)
	if piece == null or piece.role_definition_id == &"":
		return "Steward"
	var definition: SpecialistDefinition = content.get_specialist(piece.role_definition_id)
	return definition.display_name if definition != null else "Specialist"


static func piece_label(state: RunState, content: ContentRegistry, piece_id: int) -> String:
	if state.specialists == null:
		return role_name(state, content, piece_id)
	for index: int in range(state.specialists.pieces.size()):
		if state.specialists.pieces[index].piece_id == piece_id:
			return "%s · piece %d" % [role_name(state, content, piece_id), index + 1]
	return role_name(state, content, piece_id)


static func target_label(state: RunState, target_type: int, target_id: int) -> String:
	if target_type == SpecialistRules.ENCLOSURE:
		var enclosure: EnclosureState = SpecialistRules.find_enclosure(state, target_id)
		if enclosure != null:
			return "%s at (%d, %d)" % [String(enclosure.stage).capitalize(), enclosure.coordinate.x, enclosure.coordinate.y]
	else:
		var feature: CurrentFeature = SpecialistRules.find_feature(TopologyService.rebuild(state), target_id)
		if feature != null and not feature.coordinates.is_empty():
			var at: Vector2i = feature.coordinates[0]
			return "%s · %d tiles · near (%d, %d)" % [feature_name(target_type), feature.coordinates.size(), at.x, at.y]
	return feature_name(target_type)


static func feature_name(target_type: int) -> String:
	const NAMES: Array[String] = ["Road", "Settlement", "Forest", "River", "Monastery enclosure"]
	return NAMES[target_type] if target_type >= 0 and target_type < NAMES.size() else "Feature"
