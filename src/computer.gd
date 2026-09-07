extends Node3D

@onready var svp: SubViewport = $"../SubViewport"

func _unhandled_input(event: InputEvent) -> void:
    svp.push_input(event)
