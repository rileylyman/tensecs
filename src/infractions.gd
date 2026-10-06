class_name Inf
extends Node

var all: Array[Infraction] = [
    Infraction.new(042, "SMOKING", "Unauthorized Smoking"),
    Infraction.new(555, "MURDER", "Unauthorized Revocation of Life"),
    Infraction.new(136, "THEFT", "General Theft (<$100 of goods)"),
]


class Infraction:
    var code: int
    var short_name: String
    var long_name: String

    func _init(_code: int, _short_name: String, _long_name: String) -> void:
        code = _code
        short_name = _short_name
        long_name = _long_name

    func code_format() -> String:
        return "INF%03d" % code

    func short_with_code() -> String:
        return "%s - %s" % [code_format(), short_name.to_upper()]
