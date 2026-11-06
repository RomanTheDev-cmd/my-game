extends Node2D

func _draw() -> void:
	if Session.equipped.armor in ["quilted", "chain"]:
		var color := Color("718598") if Session.equipped.armor == "chain" else Color("697f68")
		draw_rect(Rect2(-4, -14, 8, 9), color)
		draw_line(Vector2(-4, -10), Vector2(4, -10), color.lightened(0.15), 1)
	if Session.equipped.weapon != "":
		var length := 18 if Session.equipped.weapon in ["polearm", "watch_spear"] else (8 if Session.equipped.weapon == "dagger" else 12)
		draw_rect(Rect2(8, -4 - length, 2, length), Color("c7d5ce"))
		draw_rect(Rect2(7, -4, 3, 5), Color("a3895b"))
		draw_rect(Rect2(5, -5, 7, 2), Color("a3895b"))
	if Session.equipped.shield != "":
		var color := Color("899d9c") if Session.equipped.shield == "iron_shield" else Color("94774e")
		draw_rect(Rect2(-12, -13, 7, 12), color.darkened(0.25))
		draw_rect(Rect2(-11, -12, 5, 9), color)
