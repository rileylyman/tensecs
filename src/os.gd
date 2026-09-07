extends Control


func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        print(event)
