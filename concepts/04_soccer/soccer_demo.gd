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
	
	# Manually create teams and link them to pitch
	var red_team = SoccerTeam.new(pitch, SoccerTeam.TeamColor.RED, pitch.red_goal, pitch.blue_goal)
	red_team.name = "RedTeam"
	pitch.add_child(red_team)
	
	var blue_team = SoccerTeam.new(pitch, SoccerTeam.TeamColor.BLUE, pitch.blue_goal, pitch.red_goal)
	blue_team.name = "BlueTeam"
	pitch.add_child(blue_team)
	
	pitch.red_team = red_team
	pitch.blue_team = blue_team

func _setup_csharp() -> void:
	print("Starting Soccer Simulation (C#)")
	var script = load("res://concepts/04_soccer/csharp/SoccerPitch.cs")
	if script:
		var pitch = script.new()
		add_child(pitch)
		
		# Team creation in C# might be tricky if we can't pass args easily via new() in GDScript 
		# or if the C# SoccerPitch creates them.
		# Let's assume we attach the scripts to nodes.
		
		var team_script = load("res://concepts/04_soccer/csharp/SoccerTeam.cs")
		if team_script:
			# We need to access C# properties or methods. 
			# GDScript can interact with C# objects if built.
			
			# Ideally, SoccerPitch in C# should handle team creation in its _Ready or Init, 
			# but our GDScript SoccerPitch didn't do that automatically to allow flexibility.
			# Let's do it here.
			
			# Red Team
			var red_team = team_script.new()
			red_team.Pitch = pitch
			red_team.Color = 0 # Red (enum value)
			red_team.HomeGoal = pitch.RedGoal
			red_team.OpponentsGoal = pitch.BlueGoal
			red_team.Name = "RedTeam"
			pitch.AddChild(red_team)
			
			# Blue Team
			var blue_team = team_script.new()
			blue_team.Pitch = pitch
			blue_team.Color = 1 # Blue
			blue_team.HomeGoal = pitch.BlueGoal
			blue_team.OpponentsGoal = pitch.RedGoal
			blue_team.Name = "BlueTeam"
			pitch.AddChild(blue_team)
			
			# pitch.RedTeam = red_team
			# pitch.BlueTeam = blue_team
