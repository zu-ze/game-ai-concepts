extends Node2D

@export var use_csharp_implementation: bool = false

func _ready() -> void:
	if use_csharp_implementation:
		setup_csharp_agents()
	else:
		setup_gdscript_agents()

func setup_gdscript_agents() -> void:
	print("--- Starting West World Demo (GDScript) ---")
	
	var miner = Miner.new()
	miner.name = "Miner"
	add_child(miner)
	
	var wife = MinnersWife.new()
	wife.name = "Elsa"
	add_child(wife)
	
	# Link them
	miner.wife = wife

func setup_csharp_agents() -> void:
	# Note: For C# agents to work, the project must be built and the classes loaded.
	# We load them by resource path or class name if registered.
	print("--- Starting West World Demo (C#) ---")
	
	# Dynamically loading C# scripts
	var miner_script = load("res://concepts/02_fsm/csharp/WestWorld/Miner.cs")
	var wife_script = load("res://concepts/02_fsm/csharp/WestWorld/MinersWife.cs")
	
	if miner_script and wife_script:
		var miner = miner_script.new()
		miner.name = "Miner"
		add_child(miner)
		
		var wife = wife_script.new()
		wife.name = "Elsa"
		add_child(wife)
		
		# Link them (assuming property exists)
		miner.Wife = wife
	else:
		push_error("Could not load C# scripts. Make sure the solution is built.")
