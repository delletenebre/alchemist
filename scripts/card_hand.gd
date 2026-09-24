class_name CardHand
extends Node2D

signal selection_changed(index: int)
signal reordered(from_index: int, to_index: int)
signal play_requested(index: int, card: IngredientCard)
signal drop_hover_changed(active: bool)

const CARD_SIZE := Vector2(240, 352)
const REST_SCALE := 0.53
const PREVIEW_SCALE := 1.14
const DRAG_SCALE := 0.72
const DRAG_THRESHOLD := 12.0

@onready var cards: Array[IngredientCard] = [$Card0, $Card1, $Card2, $Card3, $Card4, $Card5]

var focused_card: IngredientCard
var pressed_card: IngredientCard
var dragging_card: IngredientCard
var external_card: IngredientCard
var dealing := false
var has_appeared := false
var locked := false
var logical_height := 844.0
var drop_center := Vector2(195, 345)
var idle_time := 0.0
var pointer_id := -2
var press_position := Vector2.ZERO
var pointer_position := Vector2.ZERO
var drag_tilt := 0.0
var reorder_index := -1
var over_cauldron := false
var active_count := 0
var incoming: Dictionary = {}
var velocities: Dictionary = {}

func _ready() -> void:
	for card in cards:
		card.pointer_pressed.connect(press_card)
		card.visible = false
		velocities[card] = Vector2.ZERO
	get_window().focus_exited.connect(cancel_interaction)

func set_layout(height: float, mouth_position: Vector2) -> void:
	logical_height = height
	drop_center = mouth_position
	if is_instance_valid(pressed_card):
		cancel_interaction()

func set_locked(value: bool) -> void:
	locked = value
	for card in cards:
		card.set_interactive(not locked and not dealing)

func focus_card(index: int) -> void:
	if locked or dealing or index < 0 or index >= cards.size():
		return
	focused_card = cards[index]
	selection_changed.emit(index)

func dismiss() -> void:
	if is_instance_valid(pressed_card):
		return
	focused_card = null

func press_card(card: IngredientCard, pointer_global: Vector2, id: int = -1) -> void:
	if locked or dealing or is_instance_valid(pressed_card) or not cards.has(card):
		return
	pressed_card = card
	pointer_id = id
	press_position = pointer_global
	pointer_position = pointer_global
	drag_tilt = 0.0
	reorder_index = -1
	focus_card(cards.find(card))

func move_pointer(pointer_global: Vector2, id: int = -1) -> void:
	if not is_instance_valid(pressed_card) or id != pointer_id:
		return
	var movement := to_local(pointer_global) - to_local(pointer_position)
	pointer_position = pointer_global
	if not is_instance_valid(dragging_card) and pointer_global.distance_to(press_position) >= DRAG_THRESHOLD:
		dragging_card = pressed_card
		dragging_card.dragging = true
		focused_card = null
	if is_instance_valid(dragging_card):
		drag_tilt = clampf(movement.x * 0.7, -12.0, 12.0)
		_set_drop_hover(_inside_drop(_drag_center()))
		reorder_index = _hand_slot_at(pointer_global)

func release_pointer(pointer_global: Vector2, id: int = -1) -> void:
	if not is_instance_valid(pressed_card) or id != pointer_id:
		return
	pointer_position = pointer_global
	var source := pressed_card
	var was_dragging := source == dragging_card
	var should_play := was_dragging and _inside_drop(_drag_center())
	var destination_slot := _hand_slot_at(pointer_global) if was_dragging else -1
	reorder_index = -1
	pressed_card = null
	dragging_card = null
	pointer_id = -2
	source.dragging = false
	_set_drop_hover(false)
	if should_play:
		external_card = source
		focused_card = null
		set_locked(true)
		play_requested.emit(cards.find(source), source)
	elif was_dragging:
		if destination_slot >= 0:
			var from_index := cards.find(source)
			if from_index != destination_slot:
				cards.remove_at(from_index)
				cards.insert(destination_slot, source)
				reordered.emit(from_index, destination_slot)
		focused_card = null

func cancel_interaction() -> void:
	reorder_index = -1
	if is_instance_valid(pressed_card):
		pressed_card.dragging = false
	pressed_card = null
	dragging_card = null
	focused_card = null
	pointer_id = -2
	_set_drop_hover(false)

func _input(event: InputEvent) -> void:
	# Control GUI picking uses tree order, while the fan uses animated z order.
	# Pick the visible card ourselves before GUI propagation so a recycled node cannot steal taps.
	if not locked and not dealing and not is_instance_valid(pressed_card):
		var down: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.device != -1
		var touch_down: bool = event is InputEventScreenTouch and event.pressed
		if down or touch_down:
			var hit := _card_at(event.position)
			if hit:
				press_card(hit, event.position, event.index if touch_down else -1)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_interaction()
	if not is_instance_valid(pressed_card):
		return
	if event is InputEventMouseMotion and event.device != -1:
		move_pointer(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and event.device != -1:
		release_pointer(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		move_pointer(event.position, event.index)
	elif event is InputEventScreenTouch and not event.pressed:
		if event.canceled and event.index == pointer_id:
			cancel_interaction()
		else:
			release_pointer(event.position, event.index)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dismiss()
	elif event is InputEventScreenTouch and event.pressed:
		dismiss()

func _card_at(viewport_point: Vector2) -> IngredientCard:
	var best: IngredientCard
	for card in cards:
		if not card.visible or card == external_card:
			continue
		var point := card.get_global_transform_with_canvas().affine_inverse() * viewport_point
		var hits := Rect2(Vector2(8, 12), CARD_SIZE - Vector2(16, 24)).has_point(point)
		for badge in [card.smoke_badge, card.heat_badge, card.damage_badge]:
			if badge.visible and badge.get_rect().has_point(point):
				hits = true
		if hits and (best == null or card.z_index >= best.z_index):
			best = card
	return best

func _hand_slot_at(viewport_point: Vector2) -> int:
	var point := to_local(viewport_point)
	if point.y < logical_height - 220 or point.y > logical_height + 20 or point.x < -20 or point.x > 410:
		return -1
	var closest := 0
	var distance := INF
	for i in range(cards.size()):
		var offset := absf(point.x - _slot_center(i, cards.size()).x)
		if offset < distance:
			distance = offset
			closest = i
	return closest

func _drag_center() -> Vector2:
	# A touch holds the card just below its lower edge; the illustration stays above the finger.
	var offset := Vector2(-12, -CARD_SIZE.y * DRAG_SCALE * 0.5 - 18) if pointer_id >= 0 else Vector2.ZERO
	return to_local(pointer_position) + offset

func _inside_drop(point: Vector2) -> bool:
	var distance := (point - drop_center) / Vector2(100, 70)
	return distance.length_squared() <= 1.0

func _set_drop_hover(value: bool) -> void:
	if over_cauldron == value:
		return
	over_cauldron = value
	drop_hover_changed.emit(value)

func _slot_center(index: int, count: int) -> Vector2:
	var spread := minf(60.0, 215.0 / maxf(count - 1, 1))
	var x := 195.0 + (index - (count - 1) * 0.5) * spread
	var arc := absf(index - (count - 1) * 0.5) / maxf((count - 1) * 0.5, 1)
	return Vector2(x, logical_height - 115.0 + arc * arc * 11.0)

func _slot_angle(index: int, count: int) -> float:
	return (index - (count - 1) * 0.5) * minf(3.0, 14.0 / maxf(count - 1, 1))

func _preview_center() -> Vector2:
	var half := CARD_SIZE * PREVIEW_SCALE * 0.5
	return Vector2(195, maxf(185.0 + half.y, logical_height - 22.0 - half.y))

func _process(delta: float) -> void:
	idle_time += delta
	var count := mini(active_count, cards.size())
	var display_order := cards.duplicate()
	if is_instance_valid(dragging_card) and reorder_index >= 0:
		display_order.erase(dragging_card)
		display_order.insert(reorder_index, dragging_card)
	for index in range(count):
		var card := cards[index]
		if card == external_card or not card.visible:
			continue
		var display_index := display_order.find(card)
		var center := _slot_center(display_index, count)
		var angle := _slot_angle(display_index, count)
		var target_scale := REST_SCALE
		var lifted := card == focused_card or card == dragging_card
		card.set_lifted(lifted)
		if incoming.has(card):
			_advance_arrival(card, center, angle, delta)
			continue
		if card == focused_card:
			center = _preview_center()
			angle = 0.0
			target_scale = PREVIEW_SCALE
			card.z_index = 80
		elif card == dragging_card:
			center = _drag_center()
			var lag := center.x - (card.position.x + CARD_SIZE.x * 0.5)
			angle = clampf(drag_tilt + lag * 0.09, -14, 14)
			target_scale = DRAG_SCALE
			card.z_index = 100
		else:
			if is_instance_valid(focused_card):
				var focus_index := cards.find(focused_card)
				center.x += -5.0 if index < focus_index else 5.0
			center.y += sin(idle_time * 1.45 + index * 1.1) * 1.2
			angle += sin(idle_time * 1.05 + index * 1.6) * 0.55
			# Keep a returning card on top until it is back in the fan.
			card.z_index = 60 if card.scale.x > REST_SCALE + 0.06 else display_index
		_spring_to(card, center - CARD_SIZE * 0.5, delta, 19.0 if card == dragging_card else 15.0)
		card.rotation_degrees = lerpf(card.rotation_degrees, angle, 1.0 - exp(-delta * 13.0))
		card.scale = card.scale.lerp(Vector2.ONE * target_scale, 1.0 - exp(-delta * 14.0))
	drag_tilt = lerpf(drag_tilt, 0.0, 1.0 - exp(-delta * 7.0))

func _spring_to(card: IngredientCard, target: Vector2, delta: float, frequency: float) -> void:
	# Exact critically damped spring: stable across slow frames, continuous after interruptions.
	var offset := card.position - target
	var velocity: Vector2 = velocities.get(card, Vector2.ZERO)
	var impulse := velocity + offset * frequency
	var decay := exp(-frequency * delta)
	card.position = target + (offset + impulse * delta) * decay
	velocities[card] = (velocity - impulse * frequency * delta) * decay

func _advance_arrival(card: IngredientCard, target: Vector2, angle: float, delta: float) -> void:
	var elapsed: float = incoming[card] + delta
	incoming[card] = elapsed
	var t := minf(elapsed / 0.62, 1.0)
	var progress := 1.0 - pow(1.0 - t, 3.0)
	var origin := Vector2(460, logical_height + 60)
	var control := Vector2(300, logical_height - 290)
	var center := origin * pow(1.0 - progress, 2) + control * 2 * (1.0 - progress) * progress + target * progress * progress
	center.y -= sin(t * PI) * 9.0
	card.position = center - CARD_SIZE * 0.5
	card.rotation_degrees = lerpf(24.0, angle, progress) - sin(t * PI) * 4.0
	card.scale = Vector2.ONE * (lerpf(0.34, REST_SCALE, progress) + sin(t * PI) * 0.025)
	card.z_index = 40 + cards.find(card)
	if t >= 1.0:
		incoming.erase(card)
		velocities[card] = Vector2.ZERO

func deal() -> void:
	dealing = true
	set_locked(true)
	active_count = 0
	for card in cards:
		card.visible = false
	for card in cards:
		active_count += 1
		card.visible = true
		incoming[card] = 0.0
		await get_tree().create_timer(0.12).timeout
	while not incoming.is_empty():
		await get_tree().process_frame
	dealing = false
	has_appeared = true
	set_locked(false)

func take_for_play(card: IngredientCard) -> void:
	cancel_interaction()
	external_card = card
	set_locked(true)

func remove_played(card: IngredientCard) -> void:
	card.visible = false
	cards.erase(card)
	active_count = cards.size()
	external_card = null
	velocities[card] = Vector2.ZERO

func append_card(card: IngredientCard) -> void:
	cards.append(card)
	card.visible = false
	active_count = cards.size()

func deal_new_card(card: IngredientCard) -> void:
	dealing = true
	set_locked(true)
	# Existing cards first begin opening the slot, then the new card lands at the right end.
	await get_tree().create_timer(0.12).timeout
	card.visible = true
	card.modulate = Color.WHITE
	incoming[card] = 0.0
	while incoming.has(card):
		await get_tree().process_frame
	dealing = false
	set_locked(false)
