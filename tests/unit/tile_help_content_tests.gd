extends "res://tests/framework/test_suite.gd"
## Static reminders are complete, registry-owned data, never an alternative rules engine.

const REQUIRED_DETAILS: Dictionary = {
	&"tile.development.monastery": ["Field", "8 surrounding", "+5 Culture", "immediately"],
	&"tile.development.foresters_lodge": ["Forest", "undeveloped", "+1 Ecology", "immediately"],
	&"tile.development.market": ["Settlement", "+1 Trade", "OTHER Settlement", "Trade Network", "immediately"],
	&"tile.development.mill": ["Field", "+2 Population", "+1 Trade", "River", "Established"],
	&"tile.development.port": ["River", "+2 Trade", "other Port", "immediately"],
	&"tile.development.town_square": ["Settlement", "+2 Culture", "Development family", "including Town Square"],
	&"tile.development.abbey": ["Monastery", "8-space", "+8 Culture", "natural-geography", "Settlement tile", "immediately"],
	&"tile.development.grand_market": ["existing Market", "+2 Trade", "OTHER Settlement", "Trade Network", "immediately"],
	&"tile.riverside_hamlet": ["straight River Run", "Field bank", "Preserves the River", "Settlement", "no Development slot"],
	&"tile.woodland_river": ["River Bend", "Field banks", "Preserves the River", "Forest", "no Development slot"],
	&"tile.transformation.urban_expansion": ["Empty square", "Field boundaries", "reopen or merge"],
	&"tile.transformation.bridge": ["straight River Run", "No Forest-to-Road", "Preserves River", "perpendicular Road", "no Development slot"],
	&"tile.transformation.rewilding": ["Empty square", "Field-dependent", "preserving Road, Settlement and River", "no Development slot"],
	&"tile.road_junction": ["Roads terminate", "separate physical Roads", "Trade Network", "no physical Road length"],
}


func tests() -> Array[Callable]:
	var result: Array[Callable] = [all_player_tiles_have_usable_static_rules,
		rejects_missing_placement_summary, rejects_missing_effect_summary, registry_owns_rules_text]
	for id: StringName in REQUIRED_DETAILS:
		result.append(complex_tile_reminder_has_essential_rules.bind(id))
	return result


func _content() -> ContentRegistry:
	var content: ContentRegistry = ContentRegistry.new()
	assert(content.load_phase_nine().is_valid)
	return content


func all_player_tiles_have_usable_static_rules() -> bool:
	var content: ContentRegistry = _content()
	var player_count: int = 0
	for id: StringName in content.get_tile_ids():
		var tile: TileDefinition = content.get_tile(id)
		if not tile.player_drawable:
			continue
		player_count += 1
		expect_true(tile.placement_summary.strip_edges().length() > 15, "%s explains placement" % id)
		expect_true(tile.effect_summary.strip_edges().length() > 15, "%s explains its use/effect" % id)
		expect_true(tile.placement_summary.length() + tile.effect_summary.length() < 650,
			"%s reminder remains compact" % id)
	expect_equal(player_count, 28, "Every current player-acquirable design has reminders")
	return true


func rejects_missing_placement_summary() -> bool:
	return _rejects_missing_summary(true)


func rejects_missing_effect_summary() -> bool:
	return _rejects_missing_summary(false)


func _rejects_missing_summary(placement: bool) -> bool:
	var config: RunConfig = _content().get_config()
	var manifest: ContentManifest = (load(ContentRegistry.PHASE_NINE_MANIFEST_PATH) as ContentManifest).duplicate(true)
	for index: int in range(manifest.tiles.size()):
		var tile: TileDefinition = manifest.tiles[index]
		if tile.definition_id == &"tile.development.monastery":
			tile = tile.duplicate(true) as TileDefinition
			manifest.tiles[index] = tile
			if placement:
				tile.placement_summary = "  "
			else:
				tile.effect_summary = "\n"
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Missing player-facing content fails startup validation")
	expect_equal(result.error_code, &"missing_player_tile_summary", "Failure identifies missing reminder content")
	return true


func registry_owns_rules_text() -> bool:
	var content: ContentRegistry = _content()
	var tile: TileDefinition = content.get_tile(&"tile.development.monastery")
	var original: String = tile.effect_summary
	tile.effect_summary = "Caller-local text"
	expect_equal(content.get_tile(tile.definition_id).effect_summary, original,
		"Presentation receives a copy, preserving authoritative static content")
	return true


func complex_tile_reminder_has_essential_rules(id: StringName) -> bool:
	var tile: TileDefinition = _content().get_tile(id)
	var text: String = tile.placement_summary + "\n" + tile.effect_summary
	for detail: String in REQUIRED_DETAILS[id]:
		expect_true(text.contains(detail), "%s reminder includes %s" % [id, detail])
	return true
