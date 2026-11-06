extends RefCounted
static func completed_episode(session: Node) -> void:
	session.fresh()
	session.quest = 3
	session.world_state.commission = {"stage": 6, "survey": ["wheel", "archive"], "heard": ["wardens", "tenders"], "supply": "craft", "settlement": "shared"}
	session.world_state.minutes = 600
	session.gathered = ["waterworks:charter", "waterworks:north", "waterworks:south", "waterworks:awakened"]
	session.defeated = ["waterworks_guardian"]
	session.opened = ["waterworks_report"]
	session.xp = 180
	session.inventory = {"coin": 24, "herb": 3, "potion": 2}
static func vampire(session: Node) -> void:
	completed_episode(session)
	session.gathered.append_array(["nature:water", "nature:garden"])
	session.nature = {"kind": "vampire", "form": "human", "blood": 80.0, "stage": 3, "history": ["vampire"], "cure": 0, "gift": "blood"}
