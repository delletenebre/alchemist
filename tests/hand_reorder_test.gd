extends SceneTree
var game: Node
var output := "/private/tmp/alchemist_sept24_hand"
func _initialize() -> void:
	_run.call_deferred()
func mouse(point: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = root.get_final_transform() * point
	Input.parse_input_event(e)
	await process_frame
func motion(point: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = root.get_final_transform() * point
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
	await process_frame
func save(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func _run() -> void:
	create_timer(40).timeout.connect(func() -> void: quit(1))
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	game.demo_opponents = false
	game.random_seed = 42
	root.add_child(game)
	await create_timer(1.8).timeout
	var hand: CardHand = game.hand
	var initial_ids: Array[int] = game.hand_ids.duplicate()
	var expected: Array[int] = initial_ids.duplicate()
	var moved: int = expected.pop_at(1)
	expected.append(moved)
	var red: IngredientCard = hand.cards[1]
	var neighbor: IngredientCard = hand.cards[5]
	var neighbor_start := neighbor.position.x
	var press := red.get_global_transform_with_canvas() * Vector2(24, 130)
	await mouse(press, true)
	assert(hand.pressed_card == red, "Exposed red card must receive the press")
	var destination := hand.get_global_transform_with_canvas() * Vector2(306, hand.logical_height - 105)
	await motion(destination)
	await create_timer(0.6).timeout
	assert(hand.dragging_card == red and hand.reorder_index == 5)
	assert(neighbor.position.x < neighbor_start - 25, "Neighbor must visibly open the insertion gap")
	assert(game.hand_ids == initial_ids, "Preview must not commit order")
	await save("01_insertion_gap")
	await mouse(destination, false)
	await create_timer(0.65).timeout
	assert(game.hand_ids == expected)
	assert(hand.cards[5] == red)
	# Low scene-tree index, highest visual z: native tree-order picking used to choose another card.
	press = red.get_global_transform_with_canvas() * Vector2(120, 160)
	await mouse(press, true)
	await mouse(press, false)
	assert(hand.focused_card == red, "Pick the visible red card after reordering")
	await create_timer(0.5).timeout
	await save("02_selected_red")
	await game._play_selected()
	await create_timer(0.6).timeout
	assert(hand.cards[5] == red, "Recycled scene node is the last dealt card")
	press = red.get_global_transform_with_canvas() * Vector2(120, 160)
	await mouse(press, true)
	await mouse(press, false)
	assert(hand.focused_card == red, "Pick the last dealt card regardless of tree order")
	hand.cancel_interaction()
	await create_timer(0.6).timeout
	for dimensions in [Vector2i(320, 693), Vector2i(390, 650), Vector2i(1100, 700)]:
		root.size = dimensions
		await create_timer(0.7).timeout
		var hp_rect: Rect2 = game.self_panel.get_global_rect()
		for card in hand.cards:
			var transform := card.get_global_transform_with_canvas()
			for corner in [Vector2.ZERO, Vector2(240, 0)]:
				assert((transform * corner).y > hp_rect.end.y + 4, "HP must stay above resting fan")
		await save("03_layout_%dx%d" % [dimensions.x, dimensions.y])
	var bubble: Sprite2D = game.cauldron.bubbles.get_child(0)
	var before := bubble.position
	var before_scale := bubble.scale
	await create_timer(0.4).timeout
	assert(bubble.position.distance_to(before) > 0.1 and bubble.scale.distance_to(before_scale) > 0.01)
	print("Hand checks passed: red-card picking, live insertion gap, reorder, recycled picking, HP at 3 sizes, idle boil")
	quit()
