extends Node3D

var _has_started := false

func _input(event: InputEvent) -> void:
	if _has_started:
		return
	if event is InputEventKey and event.pressed:
		$CanvasLayer.queue_free()
		$AnimationPlayer.play("camera_in")
		_has_started = true
