extends Control

const DESIGN_WIDTH := 390.0
const MIN_LAYOUT_HEIGHT := 650.0
const CATEGORY_COLORS := {"red": Color("b94d3d"), "blue": Color("3e8499"), "green": Color("56855e"), "purple": Color("76558d")}
const PORTRAITS: Array[Texture2D] = [preload("res://assets/portrait_mira.png"), preload("res://assets/portrait_adi.png"), preload("res://assets/portrait_nok.png"), preload("res://assets/portrait_player.png")]
@export_range(2, 4) var player_count := 3
@export var demo_opponents := true
@export var random_seed := 0
@export var cards: Array[AlchemyIngredient] = [
	preload("res://data/ingredients/fireleaf.tres"),
	preload("res://data/ingredients/coal.tres"),
	preload("res://data/ingredients/mushroom.tres"),
	preload("res://data/ingredients/spore.tres"),
	preload("res://data/ingredients/mint.tres"),
	preload("res://data/ingredients/salt.tres"),
	preload("res://data/ingredients/stone.tres"),
	preload("res://data/ingredients/bloom.tres"),
 ]
var active_player := 2
var round_number := 0
var actors: Array[ActorPanel] = []
var actor_names: Array[String] = []
var actor_textures: Array[Texture2D] = []
var hp: Array[int] = []
var player_hands: Array[Array] = []
var hand_ids: Array[int] = []
var deck: Array[int] = []
var discard: Array[int] = []
var rng := RandomNumberGenerator.new()
var heat := 0
var smoke := 0
var selected_index := 0
var animating := false
var logical_height := 844.0
var duel_tweens: Array[Tween] = []
var layout_ready := false
var duel_key := Vector2i(-1, -1)

@onready var composition: Node2D = $Composition
@onready var cauldron: PaperCauldron = $Composition/Cauldron
@onready var mira: ActorPanel = $Composition/Mira
@onready var adi: ActorPanel = $Composition/Adi
@onready var nok: ActorPanel = $Composition/Nok
@onready var self_panel: ActorPanel = $Composition/SelfPanel
@onready var heat_meter: AlchemyMeter = $Composition/HeatMeter
@onready var smoke_meter: AlchemyMeter = $Composition/SmokeMeter
@onready var hand: CardHand = $Composition/Hand
@onready var hand_buttons: Array[IngredientCard] = hand.cards
@onready var opponent_card: IngredientCard = $Composition/Effects/OpponentCard
@onready var guide: Control = $Composition/BrewGuide
@onready var guide_title: Label = $Composition/BrewGuide/Title
@onready var guide_detail: Label = $Composition/BrewGuide/Detail
@onready var help_button: Button = $Composition/RulesHelp
@onready var turn_title: Label = $Composition/TurnTitle
@onready var next_label: Label = $Composition/NextTurn
@onready var rules_book: Control = $Composition/RulesBook
@onready var restart_button: Button = $Composition/Restart
@onready var turn_note: Node2D = $Composition/Effects/TurnNote
@onready var fire_tick: Node2D = $Composition/Effects/FireTick
@onready var beam: Line2D = $Composition/Effects/Beam
@onready var beam_head: Sprite2D = $Composition/Effects/BeamHead
@onready var damage_burst: Panel = $Composition/Effects/DamageBurst
@onready var damage_label: Label = $Composition/Effects/DamageBurst/Label

var hand_dealing: bool:
	get: return hand.dealing
var hand_has_appeared: bool:
	get: return hand.has_appeared

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players="):
			player_count = clampi(arg.trim_prefix("--players=").to_int(), 2, 4)
	if random_seed == 0:
		rng.randomize()
	else:
		rng.seed = random_seed
	actors.assign([mira, adi, nok].slice(0, player_count - 1))
	actors.append(self_panel)
	actor_names.assign(["Мира", "Ади", "Нок"].slice(0, player_count - 1))
	actor_names.append("Ты")
	actor_textures.assign(PORTRAITS.slice(0, player_count - 1))
	actor_textures.append(PORTRAITS[3])
	hp.resize(player_count)
	hp.fill(AlchemyRules.STARTING_HP)
	active_player = player_count - 1
	adi.visible = player_count >= 3
	nok.visible = player_count >= 4
	_prepare_deck()
	opponent_card.set_interactive(false)
	get_viewport().size_changed.connect(_fit_composition)
	hand.selection_changed.connect(_on_selection_changed)
	hand.reordered.connect(_on_hand_reordered)
	hand.play_requested.connect(_commit_card)
	hand.drop_hover_changed.connect(cauldron.set_drop_feedback)
	help_button.pressed.connect(_open_rules)
	rules_book.get_node("Page/Close").pressed.connect(_close_rules)
	restart_button.pressed.connect(func() -> void: get_tree().reload_current_scene())
	_fit_composition()
	_refresh_ui()
	hand.deal()

func _prepare_deck() -> void:
	for id in range(cards.size()):
		for copy in range(AlchemyRules.COPIES_PER_INGREDIENT):
			deck.append(id)
	_shuffle(deck)
	# Reserve one heater, ignition and cooler for every player before random cards are dealt.
	var starter: Array[int] = []
	for family in ["red", "green", "blue"]:
		for id in range(cards.size()):
			if cards[id].color == family:
				starter.append(id)
				break
	for i in range(player_count):
		var held: Array[int] = starter.duplicate()
		for id in held:
			deck.erase(id)
		player_hands.append(held)
	for held in player_hands:
		while held.size() < AlchemyRules.HAND_SIZE:
			held.append(_draw_card())
	hand_ids = player_hands[player_count - 1]

func _shuffle(values: Array[int]) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var value := values[i]
		values[i] = values[j]
		values[j] = value

func _draw_card() -> int:
	if deck.is_empty():
		deck.assign(discard)
		discard.clear()
		_shuffle(deck)
	assert(not deck.is_empty())
	return deck.pop_back()

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		hand.dismiss()

func _input(event: InputEvent) -> void:
	if rules_book.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_rules()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var showing_card := is_instance_valid(hand.focused_card) or is_instance_valid(hand.dragging_card)
	guide.visible = showing_card and not animating and not _is_finished()
	var compact := clampf((logical_height - 650.0) / 160.0, 0, 1)
	var guide_y := lerpf(146.0, 180.0, compact) if showing_card or animating else logical_height - 300.0
	guide.position.y = lerpf(guide.position.y, guide_y, 1.0 - exp(-delta * 16.0))
	if not animating:
		_update_preview()

func _fit_composition() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0: return
	var factor := minf(viewport_size.x / DESIGN_WIDTH, viewport_size.y / MIN_LAYOUT_HEIGHT)
	logical_height = viewport_size.y / factor
	composition.scale = Vector2.ONE * factor
	composition.position = Vector2((viewport_size.x - DESIGN_WIDTH * factor) * 0.5, 0)
	_apply_responsive_layout(logical_height)

func _apply_responsive_layout(height: float) -> void:
	logical_height = maxf(height, MIN_LAYOUT_HEIGHT)
	var compact := clampf((logical_height - 650.0) / 160.0, 0, 1)
	guide.position = Vector2(15, logical_height - 300)
	var top := lerpf(155.0, 175.0, compact)
	var pot_scale := minf(1.35, (guide.position.y - top - 28.0) / 160.0)
	cauldron.scale = Vector2.ONE * pot_scale
	cauldron.position = Vector2(195, guide.position.y - 16 - 64 * pot_scale)
	var spirit_scale := lerpf(0.82, 0.92, compact)
	heat_meter.scale = Vector2.ONE * spirit_scale
	smoke_meter.scale = Vector2.ONE * spirit_scale
	heat_meter.position = Vector2(5, cauldron.position.y - 135 * spirit_scale)
	smoke_meter.position = Vector2(385 - 112 * spirit_scale, cauldron.position.y - 135 * spirit_scale)
	hand.set_layout(logical_height, cauldron.position + cauldron.potion.position * cauldron.scale)
	rules_book.size = Vector2(390, logical_height)
	var page: Control = rules_book.get_node("Page")
	page.position = Vector2((390 - page.size.x) * 0.5, (logical_height - page.size.y) * 0.5)
	restart_button.position = guide.position + Vector2(120, 12)
	_layout_duel(false)

func _layout_duel(animate: bool) -> void:
	for tween in duel_tweens:
		if tween and tween.is_running(): tween.kill()
	duel_tweens.clear()
	var target := _target_index()
	duel_key = Vector2i(active_player, target)
	var next := AlchemyRules.next_player(hp, active_player)
	var waiting: Array[int] = []
	for i in range(player_count):
		if i != active_player and i != target: waiting.append(i)
	var compact := clampf((logical_height - 650.0) / 160.0, 0, 1)
	var top := lerpf(29.0, 34.0, compact)
	var full_scale := lerpf(0.75, 0.84, compact)
	for i in range(player_count):
		var small := waiting.has(i)
		var actor_scale := 0.43 if small else full_scale
		var center := 77.0 if i == active_player else 313.0
		if small:
			center = 195.0 if waiting.size() == 1 else 165.0 + waiting.find(i) * 60.0
		var pos := Vector2(center - 56 * actor_scale, 64.0 if small else top)
		actors[i].set_compact(small)
		if animate and layout_ready:
			var tween := create_tween().set_parallel(true)
			tween.tween_property(actors[i], "position", pos, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(actors[i], "scale", Vector2.ONE * actor_scale, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			duel_tweens.append(tween)
		else:
			actors[i].position = pos
			actors[i].scale = Vector2.ONE * actor_scale
		if i == next:
			next_label.position = Vector2(center - 40, pos.y + 145 * actor_scale + 2)
	next_label.visible = next >= 0 and not _is_finished()
	layout_ready = true

func _open_rules() -> void:
	if animating or hand.dealing: return
	hand.cancel_interaction()
	hand.set_locked(true)
	rules_book.visible = true
	rules_book.modulate.a = 0.0
	create_tween().tween_property(rules_book, "modulate:a", 1.0, 0.18)

func _close_rules() -> void:
	rules_book.visible = false
	hand.set_locked(animating or hand.dealing or _is_finished())

func _refresh_ui() -> void:
	var target := _target_index()
	if layout_ready and duel_key != Vector2i(active_player, target):
		_layout_duel(true)
	for i in range(player_count):
		actors[i].configure(actor_names[i], hp[i], actor_textures[i], target == i, active_player == i and not _is_finished())
	_show_brew_values(heat, smoke)
	for i in range(hand.cards.size()):
		_configure_card(hand.cards[i], hand_ids[i])
	turn_title.text = "ТВОЙ ХОД" if active_player == player_count - 1 else "ХОД: " + actor_names[active_player].to_upper()
	restart_button.visible = _is_finished()
	guide.visible = false
	if _is_finished():
		turn_title.text = "ПОБЕДА!" if hp[player_count - 1] > 0 else "ТЫ ВЫБЫЛ"
		next_label.visible = false
	_update_preview()

func _configure_card(view: IngredientCard, id: int) -> void:
	var data := cards[id]
	view.configure(data.short, data.effect, data.art, data.smoke, data.heat, CATEGORY_COLORS[data.color], "", false)

func _update_preview() -> void:
	if animating or _is_finished(): return
	help_button.disabled = hand.dealing
	var source := hand.dragging_card if is_instance_valid(hand.dragging_card) else hand.focused_card
	if not is_instance_valid(source):
		guide_title.text = "Брось ингредиент в котёл"
		guide_detail.text = "После карты огонь добавит +1 жар"
		guide_title.modulate = Color("503724")
		return
	var index := hand.cards.find(source)
	if index < 0 or index >= hand_ids.size(): return
	var result := _simulate(index)
	guide_title.modulate = Color("a53c30") if result.event == "overheat" else Color("503724")
	if result.event == "overheat":
		guide_title.text = "Перегрев: −3 здоровья тебе"
	elif result.event == "burst":
		var target := _target_index()
		guide_title.text = "%d урона → %s" % [result.damage, actor_names[target]] if target >= 0 else "Нет соперников"
	else:
		guide_title.text = "Котёл продолжит греться"
	guide_detail.text = "Жар %d → %d · Дым %d → %d" % [heat, result.hot_heat, smoke, result.card_smoke]

func _target_index(caster: int = -1) -> int:
	return AlchemyRules.target(hp, active_player if caster < 0 else caster)

func _on_hand_reordered(from_index: int, to_index: int) -> void:
	var moved := hand_ids[from_index]
	hand_ids.remove_at(from_index)
	hand_ids.insert(to_index, moved)
	selected_index = to_index
	_refresh_ui()

func _on_selection_changed(index: int) -> void:
	selected_index = index
	_update_preview()

func _select_card(index: int) -> void:
	if not animating and not hand.dealing: hand.focus_card(index)

func _simulate(index: int) -> Dictionary:
	return _simulate_card(hand_ids[index])

func _simulate_card(id: int) -> Dictionary:
	return AlchemyRules.resolve(heat, smoke, cards[id])

func _play_selected() -> void:
	if animating or hand.dealing: return
	await _commit_card(selected_index, hand.cards[selected_index])

func _commit_card(index: int, source: IngredientCard) -> void:
	if animating or rules_book.visible or active_player != player_count - 1 or _is_finished() or index < 0 or index >= hand_ids.size(): return
	animating = true
	help_button.disabled = true
	self_panel.cast()
	hand.take_for_play(source)
	var played_id := hand_ids[index]
	var result := _simulate(index)
	source.z_index = 100
	var mouth := cauldron.position + cauldron.potion.position * cauldron.scale
	var destination := mouth - source.size * 0.5
	var fly := create_tween().set_parallel(true)
	fly.tween_property(source, "position", destination + Vector2(0, -18), 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fly.tween_property(source, "rotation_degrees", -7.0, 0.20)
	fly.tween_property(source, "scale", Vector2.ONE * 0.38, 0.20)
	fly.chain().tween_property(source, "position", destination + Vector2(0, 10), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.parallel().tween_property(source, "scale", Vector2.ONE * 0.035, 0.18)
	fly.parallel().tween_property(source, "rotation_degrees", 11.0, 0.18)
	await fly.finished
	hand.remove_played(source)
	hand_ids.remove_at(index)
	await _resolve_reaction(result, played_id, active_player)
	discard.append(played_id)
	hand_ids.append(_draw_card())
	hand.append_card(source)
	selected_index = 0
	_refresh_ui()
	await hand.deal_new_card(source)
	hand.set_locked(true)
	if not _is_finished():
		if demo_opponents: await _run_opponents()
		else: await _announce_turn(active_player)
	animating = false
	_refresh_ui()
	hand.set_locked(_is_finished())

func _resolve_reaction(result: Dictionary, played_id: int, caster: int) -> void:
	var target := _target_index(caster)
	guide_title.modulate = Color("503724")
	guide_title.text = "Ингредиент в котле"
	guide_detail.text = "Жар %d · Дым %d" % [result.card_heat, result.card_smoke]
	cauldron.react()
	_show_brew_values(result.card_heat, result.card_smoke)
	heat_meter.ingredient_delta(cards[played_id].heat, actors[caster].card_origin())
	smoke_meter.ingredient_delta(cards[played_id].smoke, actors[caster].card_origin(), cards[played_id].heat, smoke)
	await get_tree().create_timer(0.46).timeout
	# Separate fire beat makes the automatic +1 visible instead of hiding it in the card effect.
	guide_title.text = "Огонь добавляет +1 жар"
	var effect_space: Transform2D = fire_tick.get_parent().get_global_transform().affine_inverse()
	var fire_origin: Vector2 = effect_space * cauldron.fire.global_position
	var meter_destination: Vector2 = effect_space * heat_meter.value_center()
	await fire_tick.fly(fire_origin, meter_destination)
	_show_brew_values(result.hot_heat, result.card_smoke)
	guide_detail.text = "Жар %d → %d · Дым %d" % [result.card_heat, result.hot_heat, result.card_smoke]
	await get_tree().create_timer(0.25).timeout
	if result.event == "overheat":
		for i in range(actors.size()):
			actors[i].target_ring.visible = i == caster
		guide_title.text = "ПЕРЕГРЕВ · −3 здоровья"
		guide_title.modulate = Color("a53c30")
		guide_detail.text = "Котёл обнуляется"
		await _spirits_prepare(true)
		cauldron.react()
		await _attack(caster, result.self_damage)
		hp[caster] = maxi(0, hp[caster] - result.self_damage)
	elif result.event == "burst" and target >= 0:
		guide_title.text = "%d урона → %s" % [result.damage, actor_names[target]]
		guide_detail.text = "3 дыма — удар силой жара"
		await _spirits_prepare(false)
		cauldron.react()
		await _attack(target, result.damage)
		hp[target] = maxi(0, hp[target] - result.damage)
	heat = result.heat
	smoke = result.smoke
	_show_brew_values(heat, smoke)
	if result.event != "prepare":
		heat_meter.finish_blast()
		smoke_meter.finish_blast()
	if result.event != "prepare":
		guide_detail.text = "Котёл пуст: жар 0 · дым 0"
	await get_tree().create_timer(0.2).timeout

func _living_count() -> int:
	var count := 0
	for health in hp:
		if health > 0: count += 1
	return count

func _is_finished() -> bool:
	return not hp.is_empty() and (hp[player_count - 1] <= 0 or _living_count() <= 1)

func _choose_bot_card(player: int) -> int:
	var options: Array[int] = []
	var best := -100
	for i in range(player_hands[player].size()):
		var result := _simulate_card(player_hands[player][i])
		var score: int = result.damage * 10 - result.self_damage * 100
		if score > best:
			best = score
			options.clear()
		if score == best: options.append(i)
	return options[rng.randi_range(0, options.size() - 1)] if not options.is_empty() else 0

func _run_opponents() -> void:
	hand.set_locked(true)
	for i in range(player_count - 1):
		if hp[i] <= 0 or _is_finished(): continue
		active_player = i
		_refresh_ui()
		await _announce_turn(i)
		var slot := _choose_bot_card(i)
		var id: int = player_hands[i][slot]
		var result := _simulate_card(id)
		var origin := composition.get_global_transform().affine_inverse() * actors[i].card_origin()
		_configure_card(opponent_card, id)
		opponent_card.position = origin - opponent_card.size * 0.5
		opponent_card.scale = Vector2.ONE * 0.08
		opponent_card.rotation_degrees = -10
		opponent_card.visible = true
		actors[i].cast()
		var reveal := create_tween().set_parallel(true)
		reveal.tween_property(opponent_card, "position", origin + Vector2(0, 65) - opponent_card.size * 0.5, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		reveal.tween_property(opponent_card, "scale", Vector2.ONE * 0.46, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal.tween_property(opponent_card, "rotation_degrees", 4.0, 0.26)
		await reveal.finished
		await get_tree().create_timer(0.3).timeout
		var destination := cauldron.position + cauldron.potion.position * cauldron.scale - opponent_card.size * 0.5
		var fly := create_tween().set_parallel(true)
		fly.tween_property(opponent_card, "position", destination, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.tween_property(opponent_card, "scale", Vector2.ONE * 0.035, 0.34)
		fly.tween_property(opponent_card, "rotation_degrees", -12.0, 0.34)
		await fly.finished
		opponent_card.visible = false
		await _resolve_reaction(result, id, i)
		player_hands[i].remove_at(slot)
		discard.append(id)
		player_hands[i].append(_draw_card())
		_refresh_ui()
		await get_tree().create_timer(0.25).timeout
	round_number += 1
	active_player = player_count - 1
	_refresh_ui()
	if not _is_finished(): await _announce_turn(active_player)

func _show_brew_values(heat_value: int, smoke_value: int) -> void:
	heat_meter.configure("ЖАР", heat_value, 6, "6 — перегрев")
	smoke_meter.configure("ДЫМ", smoke_value, 3, "3 — удар")
	cauldron.set_contents(heat_value, smoke_value)

func _attack(target: int, damage: int) -> void:
	var origin := cauldron.position + cauldron.potion.position * cauldron.scale
	var targets: Array[ActorPanel] = actors
	var goal := composition.get_global_transform().affine_inverse() * targets[target].card_origin()
	beam.visible = true
	beam_head.visible = true
	beam.clear_points()
	for i in range(18):
		beam.add_point(origin)
	var draw_tween := create_tween()
	draw_tween.tween_method(_beam_progress.bind(origin, goal), 0.0, 1.0, 0.42)
	await draw_tween.finished
	beam_head.visible = false
	damage_label.text = "−%d" % damage
	damage_burst.position = goal - damage_burst.size * 0.5
	damage_burst.scale = Vector2(0.25, 0.25)
	damage_burst.modulate.a = 1.0
	damage_burst.visible = true
	var target_panel: Control = targets[target].visual
	var hit := create_tween()
	hit.tween_property(damage_burst, "scale", Vector2(1.25, 1.25), 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hit.parallel().tween_property(target_panel, "rotation_degrees", -4.0, 0.08)
	hit.tween_property(target_panel, "rotation_degrees", 3.0, 0.07)
	hit.tween_property(target_panel, "rotation_degrees", 0.0, 0.08)
	hit.tween_property(damage_burst, "scale", Vector2.ONE, 0.13)
	hit.tween_interval(0.22)
	hit.tween_property(damage_burst, "modulate:a", 0.0, 0.18)
	hit.parallel().tween_property(beam, "modulate:a", 0.0, 0.18)
	await hit.finished
	damage_burst.visible = false
	beam.visible = false
	beam.modulate.a = 1.0


func _beam_progress(value: float, start: Vector2, goal: Vector2) -> void:
	var control := (start + goal) * 0.5 + Vector2(56, -28)
	beam_head.position = start * pow(1.0 - value, 2) + control * (2.0 * (1.0 - value) * value) + goal * value * value
	beam_head.rotation = (goal - start).angle() + PI * 0.5
	beam_head.scale = Vector2.ONE * (0.45 + sin(value * PI) * 0.25)
	beam.clear_points()
	for i in range(18):
		var t := value * float(i) / 17.0
		beam.add_point(start * pow(1.0 - t, 2.0) + control * (2.0 * (1.0 - t) * t) + goal * (t * t))

func _announce_turn(player: int) -> void:
	guide.visible = false
	var space: Transform2D = turn_note.get_parent().get_global_transform().affine_inverse()
	var origin: Vector2 = space * actors[player].card_origin()
	var resting := Vector2(195, lerpf(192.0, 238.0, clampf((logical_height - 650.0) / 160.0, 0, 1)))
	var caption := "Твой ход" if player == player_count - 1 else "Ходит " + actor_names[player]
	await turn_note.announce(caption, origin, resting, func() -> Vector2:
		return turn_note.get_parent().get_global_transform().affine_inverse() * cauldron.fire.global_position
	)

func _spirits_prepare(overheat: bool) -> void:
	heat_meter.prepare_blast(overheat)
	smoke_meter.prepare_blast(overheat)
	await get_tree().create_timer(0.32).timeout
	heat_meter.release_blast(overheat)
	smoke_meter.release_blast(overheat)
