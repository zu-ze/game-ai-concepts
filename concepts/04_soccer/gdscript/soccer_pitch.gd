class_name SoccerPitch extends Node2D

@export var ball_scene: PackedScene

var ball: SoccerBall
var red_goal: Goal
var blue_goal: Goal
var red_team: SoccerTeam
var blue_team: SoccerTeam
var regions: Dictionary = {} # ID -> Region
var walls: Array[Wall] = []

var pitch_width: float = 800.0
var pitch_height: float = 500.0

func _ready() -> void:
	# Initialize goals
	# Left Goal (Red Team defends left, Blue attacks left)
	# Goal Line at x = 0
	red_goal = Goal.new(Vector2(0, 180), Vector2(0, 320), Vector2(1, 0))
	
	# Right Goal (Blue Team defends right, Red attacks right)
	# Goal Line at x = pitch_width (800)
	blue_goal = Goal.new(Vector2(pitch_width, 180), Vector2(pitch_width, 320), Vector2(-1, 0))
	
	# Initialize Ball
	ball = SoccerBall.new()
	ball.position = Vector2(pitch_width/2, pitch_height/2)
	add_child(ball)
	
	# Walls
	_create_walls()
	
	# Regions (Dividing the pitch into grid for strategy)
	_create_regions(4, 3) # 4 cols, 3 rows
	
	# Initialize Teams
	red_team = SoccerTeam.new(self, SoccerTeam.TeamColor.RED, red_goal, blue_goal)
	red_team.name = "RedTeam"
	add_child(red_team)
	
	blue_team = SoccerTeam.new(self, SoccerTeam.TeamColor.BLUE, blue_goal, red_goal)
	blue_team.name = "BlueTeam"
	add_child(blue_team)

func _create_walls() -> void:
	# Top
	walls.append(Wall.new(Vector2(0, 0), Vector2(pitch_width, 0)))
	# Bottom
	walls.append(Wall.new(Vector2(pitch_width, pitch_height), Vector2(0, pitch_height)))
	# Left (excluding goal)
	walls.append(Wall.new(Vector2(0, pitch_height), Vector2(0, 320))) # Bottom-Left
	walls.append(Wall.new(Vector2(0, 180), Vector2(0, 0))) # Top-Left
	# Right
	walls.append(Wall.new(Vector2(pitch_width, 0), Vector2(pitch_width, 180))) # Top-Right
	walls.append(Wall.new(Vector2(pitch_width, 320), Vector2(pitch_width, pitch_height))) # Bottom-Right
	
	# Visual debug for walls
	queue_redraw()

func _create_regions(cols: int, rows: int) -> void:
	var cell_w = pitch_width / cols
	var cell_h = pitch_height / rows
	var id = 0
	for y in range(rows):
		for x in range(cols):
			var r = Region.new(x*cell_w, y*cell_h, (x+1)*cell_w, (y+1)*cell_h, id)
			regions[id] = r
			id += 1

func _process(delta: float) -> void:
	# Check Goals
	if red_goal.check_score(ball):
		print("Blue Team Scored!")
		ball.position = Vector2(pitch_width/2, pitch_height/2)
		ball.trap()
		red_team.state_machine.change_state(SoccerTeam.PrepareForKickOff.new())
		blue_team.state_machine.change_state(SoccerTeam.PrepareForKickOff.new())
		
	if blue_goal.check_score(ball):
		print("Red Team Scored!")
		ball.position = Vector2(pitch_width/2, pitch_height/2)
		ball.trap()
		red_team.state_machine.change_state(SoccerTeam.PrepareForKickOff.new())
		blue_team.state_machine.change_state(SoccerTeam.PrepareForKickOff.new())

func _draw() -> void:
	# Draw Pitch
	draw_rect(Rect2(0, 0, pitch_width, pitch_height), Color.FOREST_GREEN)
	# Draw Lines
	draw_line(Vector2(pitch_width/2, 0), Vector2(pitch_width/2, pitch_height), Color.WHITE, 2.0)
	draw_circle(Vector2(pitch_width/2, pitch_height/2), 50.0, Color.WHITE, false, 2.0)
	
	# Draw Goal Areas (The "box" in front of goal)
	# Red Goal Area (Left)
	draw_rect(Rect2(0, 180, 40, 140), Color(1, 0.2, 0.2, 0.3), true) # Filled red box
	draw_line(Vector2(40, 180), Vector2(40, 320), Color.WHITE, 2.0) # Front of box
	draw_line(Vector2(0, 180), Vector2(40, 180), Color.WHITE, 2.0) # Top of box
	draw_line(Vector2(0, 320), Vector2(40, 320), Color.WHITE, 2.0) # Bottom of box
	
	# Blue Goal Area (Right)
	draw_rect(Rect2(pitch_width - 40, 180, 40, 140), Color(0.2, 0.2, 1, 0.3), true) # Filled blue box
	draw_line(Vector2(pitch_width - 40, 180), Vector2(pitch_width - 40, 320), Color.WHITE, 2.0)
	draw_line(Vector2(pitch_width, 180), Vector2(pitch_width - 40, 180), Color.WHITE, 2.0)
	draw_line(Vector2(pitch_width, 320), Vector2(pitch_width - 40, 320), Color.WHITE, 2.0)
	
	# Goal Lines (Rear of box)
	draw_line(Vector2(0, 180), Vector2(0, 320), Color.RED, 4.0)
	draw_line(Vector2(pitch_width, 180), Vector2(pitch_width, 320), Color.BLUE, 4.0)
