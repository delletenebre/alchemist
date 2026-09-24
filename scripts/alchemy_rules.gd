class_name AlchemyRules
extends RefCounted

const OVERHEAT := 6
const IGNITION := 3
const SELF_DAMAGE := 3
const STARTING_HP := 12
const HAND_SIZE := 6
const COPIES_PER_INGREDIENT := 4

# Preview, players and bots use exactly the same, non-mutating resolution.
static func resolve(heat: int, smoke: int, ingredient: AlchemyIngredient) -> Dictionary:
	var card_heat := maxi(0, heat + ingredient.heat)
	var card_smoke := maxi(0, smoke + ingredient.smoke)
	var hot := card_heat + 1
	var event := "prepare"
	var damage := 0
	var self_damage := 0
	if hot >= OVERHEAT:
		event = "overheat"
		self_damage = SELF_DAMAGE
	elif card_smoke >= IGNITION:
		event = "burst"
		damage = hot
	return {"card_heat": card_heat, "card_smoke": card_smoke, "hot_heat": hot,
		"heat": hot if event == "prepare" else 0,
		"smoke": card_smoke if event == "prepare" else 0,
		"event": event, "damage": damage, "self_damage": self_damage}

static func target(health: Array[int], caster: int) -> int:
	var result := -1
	# Equal health goes to the next opponent clockwise, avoiding a permanent seat advantage.
	for offset in range(1, health.size()):
		var i := (caster + offset) % health.size()
		if health[i] > 0 and (result < 0 or health[i] > health[result]):
			result = i
	return result

static func next_player(health: Array[int], caster: int) -> int:
	for offset in range(1, health.size()):
		var i := (caster + offset) % health.size()
		if health[i] > 0:
			return i
	return -1
