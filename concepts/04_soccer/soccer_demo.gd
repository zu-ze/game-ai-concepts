extends Node2D

@export var use_csharp: bool = false

func _ready() -> void:
	if use_csharp:
		_setup_csharp()
	else:
		_setup_gdscript()

func _setup_gdscript() -> void:
	print("Starting Soccer Simulation (GDScript)")
	var pitch = SoccerPitch.new()
	add_child(pitch)
	# Pitch now creates teams internally

func _setup_csharp() -> void:
	print("Starting Soccer Simulation (C#)")
	var script = load("res://concepts/04_soccer/csharp/SoccerPitch.cs")
	if script:
		var pitch = script.new()
		add_child(pitch)
