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
	# Left Goal (Red Goal - defended by Red team? usually convention is Team Red defends left?)
	# Let's say Team Red is on Left side, Team Blue on Right.
	# So Red Defends Left Goal, Blue Defends Right Goal.
	
	red_goal = Goal.new(Vector2(40, 180), Vector2(40, 320), Vector2(1, 0))
	blue_goal = Goal.new(Vector2(760, 180), Vector2(760, 320), Vector2(-1, 0))
	
	# Initialize Ball
	ball = SoccerBall.new()
	ball.position = Vector2(pitch_width/2, pitch_height/2)
	add_child(ball)
	
	# Walls
	_create_walls()
	
	# Regions (Dividing the pitch into grid for strategy)
	_create_regions(4, 3) # 4 cols, 3 rows
	
	# Initialize Teams (done by scene usually, or code)
	# For now, we assume they are added as children or created here
	pass

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
		ball.linear_velocity = Vector2.ZERO
		
	if blue_goal.check_score(ball):
		print("Red Team Scored!")
		ball.position = Vector2(pitch_width/2, pitch_height/2)
		ball.linear_velocity = Vector2.ZERO

func _draw() -> void:
	# Draw Pitch
	draw_rect(Rect2(0, 0, pitch_width, pitch_height), Color.FOREST_GREEN)
	# Draw Lines
	draw_line(Vector2(pitch_width/2, 0), Vector2(pitch_width/2, pitch_height), Color.WHITE, 2.0)
	draw_circle(Vector2(pitch_width/2, pitch_height/2), 50.0, Color.WHITE, false, 2.0)
	# Draw Goals
	draw_rect(Rect2(0, 180, 40, 140), Color(1, 0.5, 0.5, 0.5))
	draw_rect(Rect2(760, 180, 40, 140), Color(0.5, 0.5, 1, 0.5))
