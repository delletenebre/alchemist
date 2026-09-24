class_name AlchemyMeter
extends Control

signal blast_released(overheat: bool)

const HEAT_BODY := preload("res://assets/spirits/heat_body_inward.png")
const SMOKE_BODY := preload("res://assets/spirits/smoke_body_inward.png")
const HEAT_FACES := preload("res://assets/spirits/heat_faces.tres")
const SMOKE_FACES := preload("res://assets/spirits/smoke_faces.tres")
const LEAF := preload("res://assets/spirits/leaf.svg")
const WISP := preload("res://assets/spirits/wisp.svg")
@onready var motion: Node2D = $Motion
@onready var visual: Node2D = $Motion/Visual
@onready var icon: TextureRect = $Motion/Visual/Body
@onready var value_label: Label = $Motion/Visual/Value
@onready var caption: Label = $Caption
@onready var threshold_label: Label = $Threshold
@onready var face: Node2D = $Motion/Visual/Face
@onready var artwork: AnimatedSprite2D = $Motion/Visual/Face/Artwork
@onready var fist: Node2D = $Motion/Visual/FistPivot
@onready var leaves: Node2D = $Motion/Visual/Leaves
@onready var puffs: CPUParticles2D = $Motion/Visual/Puffs
var previous_value := -1
var heat_mode := true
var idle_time := 0.0
var expression: StringName = &"sleepy"
var leaf_origins: Array[Vector2] = []
var leaf_angles: Array[float] = []
var offended_time := 0.0
var look_direction := 0.0
var blast_state: StringName = &""
var pulse: Tween
var base_face := Vector2.ZERO
var face_pose: StringName = &""
var face_tween: Tween

func _ready() -> void:
	for leaf in leaves.get_children():
		leaf_origins.append(leaf.position)
		leaf_angles.append(leaf.rotation)

func configure(label_text: String, value: int, _threshold: int = 6, threshold_text: String = "6 — перегрев") -> void:
	var next_heat := label_text == "ЖАР"
	if previous_value < 0 or next_heat != heat_mode:
		heat_mode = next_heat
		icon.texture = HEAT_BODY if heat_mode else SMOKE_BODY
		base_face = Vector2(65, 72) if heat_mode else Vector2(52, 82)
		face.position = base_face
		artwork.sprite_frames = HEAT_FACES if heat_mode else SMOKE_FACES
		artwork.scale = Vector2(0.087, 0.09) if heat_mode else Vector2(0.077, 0.082)
		face.skew = -0.06 if heat_mode else 0.06
		value_label.position.x = 35.0 if heat_mode else 21.0
		face_pose = &""
		value_label.position.y = 100.0 if heat_mode else 109.0
		value_label.add_theme_color_override("font_color", Color("6e301e") if heat_mode else Color("285963"))
		for i in range(leaves.get_child_count()):
			var leaf := leaves.get_child(i) as Sprite2D
			leaf.visible = i < 3
			leaf.texture = WISP if not heat_mode and i % 2 == 0 else LEAF
			leaf.modulate = Color("d88042") if heat_mode else (Color.WHITE if i % 2 == 0 else Color("77947a"))
		puffs.texture = LEAF if heat_mode else WISP
		puffs.color = Color("e7a951") if heat_mode else Color("eee7cd")
		puffs.direction = Vector2(1, -0.3) if heat_mode else Vector2(-1, -0.3)
	caption.text = label_text
	threshold_label.text = threshold_text
	threshold_label.add_theme_color_override("font_color", Color("953d2c") if heat_mode else Color("245e68"))
	value_label.text = str(value)
	if previous_value >= 0 and value > previous_value and blast_state == &"":
		_bounce(Vector2(0.94, 1.06), 0.30)
	previous_value = value
	_update_expression()

func ingredient_delta(delta_value: int, player_position: Vector2) -> void:
	# Intent matters: an attempt to cool zero heat still offends the ember spirit.
	if delta_value < 0:
		offended_time = 1.8
		var spirit_center := get_global_transform() * Vector2(56, 73)
		look_direction = clampf((player_position.x - spirit_center.x) / 90.0, -1.0, 1.0)
		_bounce(Vector2(1.07, 0.92), 0.30)
		_update_expression()

func _update_expression() -> void:
	if blast_state != &"":
		expression = blast_state
	elif offended_time > 0:
		expression = &"angry" if heat_mode else &"sad"
	elif heat_mode and previous_value >= 5:
		expression = &"furious"
	elif previous_value == 0:
		expression = &"sleepy" if heat_mode else &"sad"
	else:
		expression = &"happy" if (previous_value >= 2 or not heat_mode) else &"calm"

	_show_expression_art()

func _show_expression_art() -> void:
	# The expression is a complete illustrated paper face, never geometry over the art.
	var pose := expression
	if pose == &"sleepy": pose = &"calm"
	elif pose == &"charge": pose = &"furious"
	elif pose == &"explode": pose = &"release"
	if pose == face_pose: return
	face_pose = pose
	artwork.animation = pose
	if face_tween and face_tween.is_running(): face_tween.kill()
	face.scale = Vector2(1.025, 0.95)
	face_tween = create_tween()
	face_tween.tween_property(face, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	idle_time += delta
	offended_time = maxf(0, offended_time - delta)
	_update_expression()
	var furious := expression == &"furious"
	var angry := expression == &"angry"
	var sad := expression == &"sad" or expression == &"sleepy"
	var releasing := expression == &"release" or expression == &"explode"
	var intensity := 3.0 if furious else (1.9 if angry or releasing else 1.0)
	var rhythm := 1.6 if heat_mode else 1.05
	visual.position = Vector2(-56, -145) + Vector2(0, sin(idle_time * rhythm) * (1.0 if heat_mode else 2.0))
	visual.rotation = (look_direction * 0.045 if angry else 0.0) + sin(idle_time * (19.0 if furious else rhythm)) * (0.032 if furious else 0.012)
	face.position = base_face + Vector2(0, sin(idle_time * rhythm + 0.2) * 0.5)
	face.rotation = lerp_angle(face.rotation, (0.13 if heat_mode else -0.10) + (-0.025 if sad else (look_direction * 0.04 if angry else sin(idle_time * 1.1) * 0.02)), 1 - exp(-delta * 8))
	fist.visible = heat_mode and (angry or furious)
	if fist.visible:
		var side := -1.0 if look_direction < 0 and angry else 1.0
		fist.position = Vector2(13 if side < 0 else 100, 87 + sin(idle_time * 12) * 1.8)
		fist.scale.x = side
		fist.rotation = side * (0.18 + sin(idle_time * (17 if furious else 12)) * 0.18)
	for i in range(leaves.get_child_count()):
		var leaf := leaves.get_child(i) as Sprite2D
		var phase := idle_time * (1.2 + i * 0.09) * (2.2 if furious else 1.0) + i * 1.8
		leaf.position = leaf_origins[i] + Vector2(sin(phase * 0.8) * 2.3, sin(phase) * 3.0) * intensity
		leaf.rotation = leaf_angles[i] + sin(phase * 0.75) * 0.22 * intensity
		leaf.scale.x = absf(leaf.scale.y) * (0.78 + sin(phase * 0.65) * 0.20)

func _bounce(stretch: Vector2, duration: float) -> void:
	if pulse and pulse.is_running(): pulse.kill()
	pulse = create_tween()
	pulse.tween_property(motion, "scale", stretch, duration * 0.3)
	pulse.tween_property(motion, "scale", Vector2.ONE, duration * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func prepare_blast(overheat: bool) -> void:
	offended_time = 0.0
	blast_state = &"charge"
	if pulse and pulse.is_running(): pulse.kill()
	pulse = create_tween()
	pulse.tween_property(motion, "scale", Vector2(1.10, 0.86) if overheat else Vector2(0.92, 1.07), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func release_blast(overheat: bool) -> void:
	blast_released.emit(overheat)
	blast_state = &"explode" if overheat else &"release"
	puffs.amount = 15 if overheat else 9
	puffs.restart()
	puffs.emitting = true
	if pulse and pulse.is_running(): pulse.kill()
	pulse = create_tween().set_parallel(true)
	pulse.tween_property(motion, "scale", Vector2(1.15, 0.82) if not overheat else Vector2(0.86, 1.17), 0.10)
	pulse.tween_property(motion, "rotation", -0.13 if heat_mode else 0.13, 0.10)
	pulse.chain().tween_property(motion, "scale", Vector2.ONE, 0.46).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.parallel().tween_property(motion, "rotation", 0.0, 0.46)

func finish_blast() -> void:
	blast_state = &""
	offended_time = 0.0
	_update_expression()

func value_center() -> Vector2:
	return value_label.get_global_transform() * (value_label.size * 0.5)
