extends SceneTree
var game: Node
var output := "/private/tmp/alchemist_v2_visual"
func _initialize() -> void:
	_run.call_deferred()
func save(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func _run() -> void:
	create_timer(35).timeout.connect(func() -> void: quit(1))
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	game.random_seed = 42
	game.demo_opponents = false
	game.player_count = 4
	root.add_child(game)
	await create_timer(1.7).timeout
	assert(not game.has_node("Composition/Queue"))
	await save("01_four_players")
	game.hp.assign([9, 8, 10, 12])
	game.active_player = 0
	game._refresh_ui()
	await create_timer(0.5).timeout
	assert(game._target_index() == 3)
	assert(game.self_panel.target_ring.visible)
	assert(game.self_panel.scale.x > 0.7)
	assert(game.mira.scale.x > 0.7)
	assert(game.adi.scale.x < 0.5 and game.nok.scale.x < 0.5)
	await save("02_you_are_target")
	game.active_player = 3
	game._refresh_ui()
	await create_timer(0.5).timeout
	game.heat = 4
	game.smoke = 2
	game.hand_ids[1] = 2
	game._refresh_ui()
	game.hand.focus_card(1)
	await create_timer(0.5).timeout
	assert(game.guide_title.text.begins_with("5 урона"))
	await save("03_preview_burst")
	game.hand_ids[1] = 0
	game._refresh_ui()
	await process_frame
	assert(game.guide_title.text.begins_with("Перегрев"))
	await save("04_preview_overheat")
	game.hand.cancel_interaction()
	await create_timer(0.4).timeout
	game._open_rules()
	await create_timer(0.25).timeout
	assert(game.hand.locked)
	await save("05_rules")
	var body: RichTextLabel = game.rules_book.get_node("Page/Body")
	print("Rules content height: ",body.get_content_height()," available: ",body.size.y)
	game._close_rules()
	for dims in [Vector2i(320, 693), Vector2i(390, 650), Vector2i(1100, 700)]:
		root.size = dims
		await create_timer(0.6).timeout
		for card in game.hand.cards:
			var transform: Transform2D = card.get_global_transform_with_canvas()
			for corner in [Vector2.ZERO, Vector2(240, 0)]:
				assert((transform * corner).y > game.guide.get_global_rect().end.y)
		await save("06_%dx%d" % [dims.x,dims.y])
	root.size = Vector2i(390, 844)
	await create_timer(0.3).timeout
	game.hand.focus_card(2)
	await create_timer(0.5).timeout
	for id in range(game.cards.size()):
		var card: IngredientCard = game.hand.cards[2]
		game._configure_card(card,id)
		await process_frame
		assert(card.title.get_line_count() <= 2)
		assert(card.effect_label.upper.get_line_count() <= 4)
		assert(not card.damage_badge.visible)
	await save("07_new_card")
	print("PRESENTATION PASS: four-player duel, local target, forecast, rules, responsive layouts, eight readable cards")
	quit()
