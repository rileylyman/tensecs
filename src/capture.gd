class_name Capture
extends Resource

@export var name: String
@export var year: int = 1642
@export var month: T.Month
@export_range(1, 31) var day: int = 1
@export_range(0, 23) var hour: int = 0
@export_range(0, 59) var minute: int = 0
@export_range(0, 59) var second: int = 0
@export var location: I.Location
@export var infractions: Array[I.Infraction]
@export var image: Texture2D
@export var scene: PackedScene
@export var vignette: PackedScene
@export var learn_infraction: I.Infraction
@export_multiline var transcript: String