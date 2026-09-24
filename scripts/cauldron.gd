class_name PaperCauldron
extends Node2D

@onready var body: Sprite2D = $Body
@onready var potion: Sprite2D = $Potion
@onready var fire: Sprite2D = $Fire
@onready var steam: Sprite2D = $Steam
@onready var drop_rim: Line2D = $DropRim
@onready var splash: CPUParticles2D = $Splash

@onready var bubbles: Node2D = $Boiling
@onready var ripples: Node2D = $Ripples
var bubble_origins: Array[Vector2] = []
var boil_time := 0.0
var idle_time := 0.0

func _ready() -> void:
	for bubble in bubbles.get_children():
		bubble_origins.append(bubble.position)
var reacting := false
var drop_active := false
var hover_amount := 0.0
var current_heat := 1
var current_smoke := 2

func set_contents(heat: int, smoke: int) -> void:
	current_heat = heat
	current_smoke = smoke

func set_drop_feedback(active: bool) -> void:
	drop_active = active

func _process(delta: float) -> void:
	idle_time += delta
	if not reacting:
		rotation = sin(idle_time * 1.45) * 0.017 + sin(idle_time * 2.3) * 0.005
		potion.position.y = -48.0 + sin(idle_time * 2.1) * 1.2
		potion.rotation = sin(idle_time * 1.7) * 0.014
		potion.scale.y = potion.scale.x * (0.97 + sin(idle_time * 2.4) * 0.025)
		fire.scale.y = fire.scale.x * (0.65 + current_heat * 0.09 + sin(idle_time * 7.0) * 0.06)
	_animate_boil(delta)
	steam.position.x = sin(idle_time * 0.9) * 7.0
	steam.position.y = -75.0 - sin(idle_time * 1.1) * 4.0
	steam.rotation = sin(idle_time * 0.75) * 0.065
	steam.scale = Vector2(0.055 * (1.0 + sin(idle_time * 0.85) * 0.08), 0.055 * (1.0 + sin(idle_time * 1.2) * 0.10))
	steam.modulate.a = minf(0.12 + current_smoke * 0.12, 0.85) + sin(idle_time * 1.5) * 0.04
	fire.modulate = Color(1.0, 0.91 + sin(idle_time * 5.0) * 0.05, 0.82, 1.0)
	hover_amount = lerpf(hover_amount, 1.0 if drop_active else 0.0, 1.0 - exp(-delta * 12.0))
	drop_rim.modulate.a = hover_amount * (0.78 + sin(idle_time * 4.0) * 0.12)

func _animate_boil(delta: float) -> void:
	# Staggered growth, release and spreading rings; positions are authored in the scene.
	boil_time += delta * (0.40 + current_heat * 0.065)
	for i in range(bubbles.get_child_count()):
		var bubble := bubbles.get_child(i) as Sprite2D
		var ripple := ripples.get_child(i) as Sprite2D
		var phase := fposmod(boil_time + i * 0.173, 1.0)
		var growth := clampf(phase / 0.73, 0.0, 1.0)
		var radius := (0.12 + growth * 0.28) * (0.90 + current_heat * 0.035)
		bubble.position = bubble_origins[i] + Vector2(sin(phase * TAU + i) * 1.4, -growth * 4.5)
		bubble.scale = Vector2(radius, radius * (0.70 + growth * 0.30))
		bubble.modulate.a = smoothstep(0.0, 0.10, phase) * (1.0 - smoothstep(0.72, 0.79, phase))
		var release := clampf((phase - 0.72) / 0.28, 0.0, 1.0)
		ripple.scale = Vector2.ONE * lerpf(0.28, 0.95, release)
		ripple.modulate.a = sin(release * PI) * 0.72

func react() -> void:
	reacting = true
	var base_scale := scale
	var base_potion := potion.scale
	var base_fire := fire.scale
	splash.restart()
	splash.emitting = true
	var reaction := create_tween()
	reaction.tween_property(self, "scale", base_scale * Vector2(1.07, 0.94), 0.09)
	reaction.parallel().tween_property(self, "rotation_degrees", -2.3, 0.09)
	reaction.parallel().tween_property(potion, "scale", base_potion * Vector2(1.1, 0.85), 0.09)
	reaction.parallel().tween_property(fire, "scale", base_fire * Vector2(1.04, 1.25), 0.09)
	reaction.tween_property(self, "scale", base_scale * Vector2(0.97, 1.04), 0.13)
	reaction.parallel().tween_property(self, "rotation_degrees", 1.5, 0.13)
	reaction.tween_property(self, "scale", base_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reaction.parallel().tween_property(self, "rotation_degrees", 0.0, 0.22)
	reaction.parallel().tween_property(potion, "scale", base_potion, 0.22)
	reaction.parallel().tween_property(fire, "scale", base_fire, 0.22)
	reaction.tween_callback(func() -> void: reacting = false)
