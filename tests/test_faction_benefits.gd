extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Trade = preload("res://scripts/items/trade_rules.gd")
const Items = preload("res://scripts/items/inventory_rules.gd")
var checks := 0
var failures := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void:
	call_deferred("run")
func find_button(game: Node, name: String) -> Button:
	return game.screen.find_child(name, true, false) as Button
func press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = key
	event.pressed = false
	root.push_input(event)
	await process_frame
func run() -> void:
	check("watch_spear" not in Trade.stock() and "watch_spear" in Trade.stock("wardens"), "exclusive equipment belongs to appropriate vendor stock")
	check(Trade.stock("missing").is_empty(), "unknown group cannot sell arbitrary stock")
	check(Items.brew_with_tender({"herb": 3}, 1).is_empty(), "service cannot bypass relationship requirement")
	check(Items.brew_with_tender({"herb": 3}, 2).get("herb") == 1, "initial trust reduces actual service cost to two herbs")
	check(Items.brew_with_tender({"herb": 3}, 3).get("herb") == 1, "high trust preserves the safe minimum ingredient cost")
	check(Items.brew_with_tender({"herb": 3, "potion": 999}, 3).is_empty(), "full supply rejects service instead of losing ingredients")
	check(Items.craft("potion", {"herb": 2}).is_empty(), "benefit remains a cooperative service, not free portable crafting")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	session.region = "workshop"
	session.arrival = Vector2(360, 540)
	session.inventory = {"coin": 50, "herb": 3}
	game._build_world()
	game.resume()
	game.world.interact()
	var shop := find_button(game, "warden_shop")
	check(shop != null and shop.disabled and not game.world.trade("watch_spear", false), "locked faction shop is enforced by both UI and transaction")
	session.world_state.reputation.wardens = 2
	game.world.interact()
	shop = find_button(game, "warden_shop")
	check(shop != null and not shop.disabled, "earned trust unlocks actual supply interface")
	await process_frame
	await process_frame
	check(root.gui_get_focus_owner() == shop, "unlocked faction action receives initial keyboard focus")
	await press_key(KEY_DOWN)
	check(root.gui_get_focus_owner() != shop and root.gui_get_focus_owner() is Button, "arrow key reaches the dialog exit")
	await press_key(KEY_UP)
	check(root.gui_get_focus_owner() == shop, "arrow key returns to faction action")
	await press_key(KEY_ENTER)
	check(game.current_screen == "shop", "faction action opens real shared shop")
	var buy := find_button(game, "trade_watch_spear")
	check(buy != null and not buy.disabled and find_button(game, "trade_herb") == null, "shop offers its own stock with available purchase")
	if buy != null:
		buy.pressed.emit()
	check(session.inventory.coin == 31 and "watch_spear" in session.gear_owned, "faction purchase transfers exclusive item at shown base price")
	check(not game.world.trade("herb", false) and session.inventory.coin == 31, "backend rejects goods outside current faction stock")
	game.show_equipment()
	var equip := find_button(game, "equip_watch_spear")
	if equip != null:
		equip.pressed.emit()
	check(session.equipped.weapon == "watch_spear" and session.equipped.shield == "", "exclusive two-handed weapon uses real equipment rules")
	var tested_reach := false
	for child in game.world.get_children():
		if child is CharacterBody2D and child.has_signal("defeated") and child.id == "workshop_1":
			var original: Vector2 = child.position
			child.position = game.world.player.position + Vector2(75, 0)
			game.world._on_strike(game.world.player.position, Vector2.RIGHT)
			tested_reach = true
			check(child.health == 43, "new weapon changes actual reachable strike damage")
			child.position = original
			break
	check(tested_reach, "weapon reach is tested against an actual hostile body")
	game.world.player.position = Vector2(600, 550)
	check(not game.world.trade("potion", false), "faction shop cannot be accessed remotely")
	game.world.player.position = game.world.npcs.warden.position
	session.world_state.reputation.wardens = 3
	check(game.world.trade("potion", false) and session.inventory.coin == 27, "higher faction trust changes actual paid price")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.trade("iron_shield", false) and session.inventory.coin == 27 and "iron_shield" not in session.gear_owned, "failed faction trade save neither charges nor grants equipment")
	DirAccess.remove_absolute("user://save.json.tmp")
	game.resume()
	game.world.player.position = game.world.npcs.tender.position
	session.world_state.reputation.tenders = 1
	check(not game.world.brew_with_tender() and session.inventory.herb == 3, "unearned recipe assistance is unavailable at the real NPC")
	session.world_state.reputation.tenders = 2
	check(game.world.brew_with_tender() and session.inventory.herb == 1 and session.inventory.potion == 2, "trusted service spends two herbs and creates one real potion")
	session.world_state.reputation.tenders = 3
	session.inventory.herb = 2
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.brew_with_tender() and session.inventory.herb == 2 and session.inventory.potion == 2, "failed assisted recipe save retains all ingredients")
	DirAccess.remove_absolute("user://save.json.tmp")
	game.world.interact()
	var brew := find_button(game, "tender_brew")
	check(brew != null and not brew.disabled, "trusted service appears as an actionable native button")
	await process_frame
	await process_frame
	check(root.gui_get_focus_owner() == brew, "assisted recipe receives keyboard focus without a mouse")
	await press_key(KEY_ENTER)
	check(session.inventory.herb == 0 and session.inventory.potion == 3, "actual service button applies the shown ingredient cost")
	check(session.load_saved() and session.world_state.reputation.tenders == 3 and "watch_spear" in session.gear_owned, "relationship benefits and owned item survive real reload")
	game._build_world()
	game.resume()
	game.world.player.position = Vector2(900, 600)
	check(not game.world.brew_with_tender(), "assisted recipe cannot be invoked away from its NPC")
	print("Faction benefit checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
