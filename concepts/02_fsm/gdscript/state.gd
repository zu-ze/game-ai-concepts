class_name State extends RefCounted

# Abstract Base Class for States

func enter(_entity: Node) -> void:
	pass

func execute(_entity: Node) -> void:
	pass

func exit(_entity: Node) -> void:
	pass

func on_message(_entity: Node, _telegram: Telegram) -> bool:
	return false
