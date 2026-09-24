extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for count in [2,3,4]:
		var game = load("res://scenes/main.tscn").instantiate()
		game.player_count = count
		game.random_seed = 42
		game.demo_opponents = false
		root.add_child(game)
		var total_turns := 0
		var longest := 0
		var timed_out := 0
		var bursts := 0
		var overheats := 0
		for match_index in range(100):
			game.deck.clear()
			game.discard.clear()
			game.player_hands.clear()
			game._prepare_deck()
			game.hp.fill(12)
			game.heat = 0
			game.smoke = 0
			var caster: int = match_index % count
			var turns := 0
			while game._living_count() > 1 and turns < 300:
				var slot: int = game._choose_bot_card(caster)
				var id: int = game.player_hands[caster][slot]
				var r: Dictionary = game._simulate_card(id)
				var target: int = game._target_index(caster)
				if r.damage > 0:
					game.hp[target] = maxi(0, game.hp[target] - r.damage)
					bursts += 1
				if r.self_damage > 0:
					game.hp[caster] = maxi(0, game.hp[caster] - r.self_damage)
					overheats += 1
				game.heat = r.heat
				game.smoke = r.smoke
				game.player_hands[caster].remove_at(slot)
				game.discard.append(id)
				game.player_hands[caster].append(game._draw_card())
				caster = AlchemyRules.next_player(game.hp, caster)
				turns += 1
			total_turns += turns
			longest = maxi(longest, turns)
			if turns == 300: timed_out += 1
		print("BALANCE PROBE players=",count," mean_turns=",total_turns/100.0," max=",longest," timeouts=",timed_out," bursts=",bursts," overheats=",overheats)
		assert(timed_out == 0)
		await create_timer(1.7).timeout
		game.queue_free()
		await process_frame
	quit()
