@tool
extends EditorPlugin

func _enter_tree():
	add_custom_type(
		"AxoContainer",
		"Container",
		preload("custom_class/axo_container.gd"),
		preload("icon.svg"),
	)


func _exit_tree():
	remove_custom_type("AxoContainer")
