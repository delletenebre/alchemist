class_name PlayerPanel
extends Control

@export var normal_style: StyleBox
@export var target_style: StyleBox

@onready var panel: Panel = $Panel
@onready var portrait: TextureRect = $Panel/Portrait
@onready var hp_label: Label = $Panel/HP


func configure(actor_hp: int, texture: Texture2D, targeted: bool) -> void:
	hp_label.text = "♥ %d" % actor_hp
	portrait.texture = texture
	panel.add_theme_stylebox_override("panel", target_style if targeted else normal_style)
