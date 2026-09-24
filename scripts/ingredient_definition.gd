class_name AlchemyIngredient
extends Resource

@export var short := ""
@export_multiline var effect := ""
@export_enum("red", "green", "blue", "purple") var color := "red"
@export var heat := 0
@export var smoke := 0
@export var art: Texture2D
