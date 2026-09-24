class_name ActorPanel
extends Control
@export var portrait_center := Vector2(56, 55)
@onready var visual: Control = $Visual
@onready var portrait: TextureRect = $Visual/Portrait
@onready var name_label: Label = $Visual/Name
@onready var hp_label: Label = $Visual/HP
@onready var target_ring: TextureRect = $Visual/TargetRing
@onready var turn_ring: TextureRect = $Visual/TurnRing
@onready var turn_aura: Node2D = $Visual/TurnAura
var active_turn := false
var time := 0.0
var cast_tween: Tween

func configure(actor_name: String, actor_hp: int, texture: Texture2D, targeted: bool, active: bool = false) -> void:
	name_label.text = actor_name
	hp_label.text = "♥ %d" % actor_hp
	portrait.texture = texture
	target_ring.visible = targeted
	turn_ring.visible = active and not targeted
	active_turn = active
	portrait.modulate = Color.WHITE if actor_hp > 0 else Color(0.5, 0.5, 0.5, 1)

func _process(delta: float) -> void:
	time += delta
	visual.position.y = lerpf(visual.position.y, -2.0 - sin(time * 3.0) * 1.6 if active_turn else 0.0, 1.0 - exp(-delta * 10.0))
	turn_ring.visible = active_turn and not target_ring.visible
	turn_ring.modulate.a = 0.90 + sin(time * 2.6) * 0.10
	turn_aura.visible = turn_ring.visible or target_ring.visible
	turn_aura.modulate = Color(1.0, 0.34, 0.24, 1.0) if target_ring.visible else Color.WHITE
	turn_aura.get_node("Glow").modulate.a = 0.72 + sin(time * 2.6) * 0.22
	for i in range(5):
		var fly := turn_aura.get_child(i + 1) as Sprite2D
		# Wander around the upper rim; never cross the name or health ribbon.
		var angle := PI + 0.12 + float(i) * 0.72 + sin(time * 0.65 + i * 1.8) * 0.16
		var radius := 57.0 + sin(time * 1.1 + i * 2.0) * 3.0
		fly.position = Vector2(56, 56) + Vector2(cos(angle), sin(angle)) * radius
		fly.modulate.a = 0.35 + (sin(time * 2.1 + i * 2.3) + 1.0) * 0.30
		fly.scale = Vector2.ONE * (0.5 + (sin(time * 1.8 + i) + 1.0) * 0.12)

func cast() -> void:
	if cast_tween and cast_tween.is_running():
		cast_tween.kill()
	cast_tween = create_tween()
	cast_tween.tween_property(visual, "scale", Vector2(0.96, 1.04), 0.10)
	cast_tween.tween_property(visual, "scale", Vector2(1.08, 0.96), 0.13)
	cast_tween.tween_property(visual, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func card_origin() -> Vector2:
	return visual.get_global_transform() * portrait_center

func set_compact(compact: bool) -> void:
	name_label.visible = not compact
	hp_label.add_theme_font_size_override("font_size", 30 if compact else 22)
	hp_label.offset_top = 98.0 if compact else 107.0
	hp_label.offset_bottom = 137.0 if compact else 130.0
