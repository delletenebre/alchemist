extends SceneTree
var game: Node
var card: IngredientCard
var start := Vector2.ZERO
var end := Vector2.ZERO
var output := "/private/tmp/alchemist-v2-frames"
func _initialize() -> void:
	_record.call_deferred()
func _record() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.random_seed = 42
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(output)
	root.gui_disable_input = true
	game.hand.set_process_input(false)
	game.hand.set_process_unhandled_input(false)
	root.focus_exited.disconnect(game.hand.cancel_interaction)
	# A reproducible mid-match situation from the rule explanation: heat 4, smoke 2.
	for frame in range(1320):
		await process_frame
		if frame == 100:
			game.heat = 4
			game.smoke = 2
			game._refresh_ui()
		elif frame == 120:
			game.hand.focus_card(1)
		elif frame == 240:
			card = game.hand.cards[1]
			start = card.get_global_transform_with_canvas() * Vector2(120, 130)
			end = game.hand.get_global_transform_with_canvas() * game.hand.drop_center
			game.hand.press_card(card,start)
		elif frame > 240 and frame < 300:
			game.hand.move_pointer(start.lerp(end,smoothstep(0,1,(frame-240)/59.0)))
		elif frame == 300:
			game.hand.release_pointer(end)
		RenderingServer.force_draw()
		if frame % 3 == 0:
			root.get_texture().get_image().save_png(output.path_join("%04d.png" % (frame / 3)))
	assert(game.round_number == 1 and not game.animating)
	print("RECORD PASS: forecast, cast, automatic fire, damage, changing duel, opponent hands")
	quit()
