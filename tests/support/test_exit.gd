extends RefCounted

static func finish(tree: SceneTree, code: int = 0) -> void:
	var sound := tree.root.get_node_or_null("Sound")
	if sound != null and sound.is_inside_tree():
		await sound.shutdown()
	tree.quit(code)
