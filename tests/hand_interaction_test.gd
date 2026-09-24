extends SceneTree

var game: Node
var capture_dir := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = root.get_final_transform() * point
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	await process_frame

func _save(label: String) -> void:
	if capture_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png"))

func _run() -> void:
	create_timer(35).timeout.connect(func() -> void: quit(1))
	game = load("res://scenes/main.tscn").instantiate()
	game.demo_opponents = false
	game.random_seed = 42
	root.add_child(game)
	await create_timer(1.7).timeout
	var hand: CardHand = game.hand
	var initial_ids: Array[int] = game.hand_ids.duplicate()
	assert(hand.has_appeared and not hand.dealing)
	await _save("01_hand")
	var card: IngredientCard = hand.cards[2]
	var point := card.get_global_transform_with_canvas() * Vector2(30, 100)
	await _mouse(point, true)
	await _mouse(point, false)
	await create_timer(0.55).timeout
	assert(hand.focused_card == card, "Click through actual GUI routing must focus the tapped card")
	assert(hand.dragging_card == null)
	assert(card.scale.x > 1.10)
	await _save("02_read")
	var frame_font := card.effect_label.upper.get_theme_font_size("font_size")
	var canvas_scale := root.get_final_transform().get_scale().x
	var text_pixels := frame_font * card.get_global_transform_with_canvas().get_scale().x * canvas_scale
	print("Focused text pixels: ", text_pixels)
	assert(text_pixels >= 16.0)
	for data in game.cards:
		card.configure(data.short, data.effect, data.art, data.smoke, data.heat, game.CATEGORY_COLORS[data.color], "", true)
		await process_frame
		assert(card.effect_label.upper.get_line_count() <= 4, "Long effects must fit beside the flame: " + data.effect)
	card.configure(game.cards[6].short, game.cards[6].effect, game.cards[6].art, 0, 1, game.CATEGORY_COLORS.red, "", true)
	await process_frame
	await _save("03_wrapping")
	game._refresh_ui()
	point = card.get_global_transform_with_canvas() * Vector2(120, 160)
	await _mouse(point, true)
	await _motion(point + Vector2(70, -100))
	await create_timer(0.18).timeout
	assert(hand.dragging_card == card)
	assert(absf(card.rotation_degrees) > 0.5)
	await _save("04_drag")
	# Releasing outside the cauldron returns the same card without consuming it.
	await _mouse(Vector2(12, 180), false)
	await create_timer(0.65).timeout
	assert(hand.dragging_card == null and hand.focused_card == null)
	assert(game.hand_ids == initial_ids)
	assert(is_equal_approx(card.modulate.a, 1.0))
	assert(absf(card.scale.x - CardHand.REST_SCALE) < 0.02)
	# Focus can be dismissed on an empty area of the table.
	point = card.get_global_transform_with_canvas() * Vector2(30, 100)
	await _mouse(point, true)
	await _mouse(point, false)
	await create_timer(0.45).timeout
	await _mouse(Vector2(195, 215), true)
	await _mouse(Vector2(195, 215), false)
	assert(hand.focused_card == null)
	# Touch input owns one pointer; a second finger cannot steal or release a card.
	point = card.get_global_transform_with_canvas() * Vector2(30, 100)
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.position = root.get_final_transform() * point
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	assert(hand.pressed_card == card and hand.pointer_id == 2)
	var other_touch := InputEventScreenTouch.new()
	other_touch.index = 3
	other_touch.position = root.get_final_transform() * Vector2(195, 215)
	other_touch.pressed = true
	Input.parse_input_event(other_touch)
	await process_frame
	assert(hand.pressed_card == card and hand.focused_card == card)
	other_touch.pressed = false
	Input.parse_input_event(other_touch)
	await process_frame
	assert(hand.pressed_card == card)
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 2
	touch_drag.position = root.get_final_transform() * (point + Vector2(50, -80))
	Input.parse_input_event(touch_drag)
	await create_timer(0.3).timeout
	assert(hand.dragging_card == card)
	var visible_center := card.position + card.size * 0.5
	assert(visible_center.y < hand.to_local(root.get_final_transform().affine_inverse() * touch_drag.position).y - 60.0)
	touch.position = touch_drag.position
	touch.pressed = false
	touch.canceled = true
	Input.parse_input_event(touch)
	await create_timer(0.5).timeout
	assert(hand.dragging_card == null and hand.focused_card == null)
	# Resize during focus keeps the card inside the viewport and preserves its identity.
	hand.focus_card(2)
	await create_timer(0.4).timeout
	var old_size := root.size
	root.size = Vector2i(390, 650)
	await create_timer(0.5).timeout
	assert(hand.focused_card == card)
	var rect := card.get_global_rect()
	assert(rect.position.x >= 0 and rect.position.y >= 0)
	assert(rect.end.x <= root.get_visible_rect().size.x + 1 and rect.end.y <= root.get_visible_rect().size.y + 1)
	root.size = old_size
	hand.dismiss()
	await create_timer(0.5).timeout
	# Drag the first card into the cauldron through the same input path.
	card = hand.cards[0]
	point = card.get_global_transform_with_canvas() * Vector2(30, 100)
	await _mouse(point, true)
	var mouth := hand.get_global_transform_with_canvas() * hand.drop_center
	await _motion(mouth)
	await create_timer(0.4).timeout
	assert(hand.over_cauldron)
	await _save("05_drop_target")
	await _mouse(mouth, false)
	await create_timer(4.0).timeout
	assert(game.hp == [12, 12, 12])
	assert(game.heat == 3 and game.smoke == 0)
	assert(game.hand_ids.slice(0, 5) == initial_ids.slice(1))
	assert(hand.cards[5] == card)
	assert(hand.cards.size() == 6 and not hand.locked and not game.animating)
	await _save("06_new_card")
	print("Hand interaction checks passed: tap, readable focus, wrapping, drag tilt, cancel, drop, damage and draw order")
	quit()
