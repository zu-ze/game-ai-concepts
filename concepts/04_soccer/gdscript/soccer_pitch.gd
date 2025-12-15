class_name SoccerPitch extends Node2D

@export var ball_scene: PackedScene

var ball: SoccerBall
var red_goal: Goal
var blue_goal: Goal
var red_team: Node2D
var blue_team: Node2D
var regions: Dictionary = {} # ID -> Region
var walls: Array[Wall] = []

var pitch_width: float = 800.0
var pitch_height: float = 500.0

# Score tracking
var red_score: int = 0
var blue_score: int = 0

# Authoritative ball control
var controlling_team: Node2D = null  # Which team controls the ball
var control_changed_time: float = 0.0  # Time when control last changed
const CONTROL_CHANGE_COOLDOWN: float = 0.5  # Seconds before control can change again

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
	# Start ball in red team's attacking zone
	ball.position = Vector2(pitch_width * 0.4, pitch_height/2)
	add_child(ball)
	
	# Walls
	_create_walls()
	
	# Regions (Dividing the pitch into grid for strategy)
	_create_regions(8, 3) # 8 cols, 3 rows
	
	# Initialize Teams
	red_team = SoccerTeam.new(self, SoccerTeam.TeamColor.RED, red_goal, blue_goal)
	red_team.name = "RedTeam"
	add_child(red_team)
	
	blue_team = SoccerTeam.new(self, SoccerTeam.TeamColor.BLUE, blue_goal, red_goal)
	blue_team.name = "BlueTeam"
	add_child(blue_team)

func _create_walls() -> void:
	# Create both logical walls and physical collision walls
	var wall_defs = [
		[Vector2(0, 0), Vector2(pitch_width, 0)], # Top
		[Vector2(pitch_width, pitch_height), Vector2(0, pitch_height)], # Bottom
		[Vector2(0, pitch_height), Vector2(0, 320)], # Bottom-Left
		[Vector2(0, 180), Vector2(0, 0)], # Top-Left
		[Vector2(pitch_width, 0), Vector2(pitch_width, 180)], # Top-Right
		[Vector2(pitch_width, 320), Vector2(pitch_width, pitch_height)] # Bottom-Right
	]
	
	for def in wall_defs:
		# Logical wall for steering behavior queries
		walls.append(Wall.new(def[0], def[1]))
		
		# Physical wall for collision
		_create_physical_wall(def[0], def[1])
	
	# Visual debug for walls
	queue_redraw()

func _create_physical_wall(from: Vector2, to: Vector2) -> void:
	var wall_body = StaticBody2D.new()
	wall_body.collision_layer = 1  # Layer 1: Walls
	wall_body.collision_mask = 0   # Walls don't need to detect anything
	
	var collision_shape = CollisionShape2D.new()
	var segment = SegmentShape2D.new()
	segment.a = from
	segment.b = to
	collision_shape.shape = segment
	
	wall_body.add_child(collision_shape)
	add_child(wall_body)

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
	# Update ball control FIRST (authoritative)
	_update_ball_control(delta)
	
	# Force UI redraw every frame
	queue_redraw()
	
	# Check Goals
	if red_goal.check_score(ball):
		blue_score += 1
		print("Blue Team Scored! Score: Red %d - Blue %d" % [red_score, blue_score])
		ball.position = Vector2(pitch_width/2, pitch_height/2)
		ball.trap()
		controlling_team = null
		control_changed_time = 0.0
		# Red team (who was scored on) gets kickoff
		red_team.state_machine.change_state(SoccerTeam.PrepareForKickOff.new(SoccerTeam.TeamColor.RED))
		blue_team.state_machine.change_state(SoccerTeam.PrepareForKickOff.new(SoccerTeam.TeamColor.RED))
		
	if blue_goal.check_score(ball):
		red_score += 1
		print("Red Team Scored! Score: Red %d - Blue %d" % [red_score, blue_score])
		ball.position = Vector2(pitch_width/2, pitch_height/2)
		ball.trap()
		controlling_team = null
		control_changed_time = 0.0
		# Blue team (who was scored on) gets kickoff
		red_team.state_machine.change_state(SoccerTeam.PrepareForKickOff.new(SoccerTeam.TeamColor.BLUE))
		blue_team.state_machine.change_state(SoccerTeam.PrepareForKickOff.new(SoccerTeam.TeamColor.BLUE))
	
	# Clamp players to pitch boundaries
	_clamp_players_to_pitch()

func _clamp_players_to_pitch() -> void:
	# Clamp all players to pitch boundaries
	for p in red_team.players:
		p.global_position.x = clamp(p.global_position.x, 10, pitch_width - 10)
		p.global_position.y = clamp(p.global_position.y, 10, pitch_height - 10)
	
	for p in blue_team.players:
		p.global_position.x = clamp(p.global_position.x, 10, pitch_width - 10)
		p.global_position.y = clamp(p.global_position.y, 10, pitch_height - 10)
	
	# Clamp ball
	ball.global_position.x = clamp(ball.global_position.x, 5, pitch_width - 5)
	ball.global_position.y = clamp(ball.global_position.y, 5, pitch_height - 5)

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
	
	# Draw region grid for debugging (optional, semi-transparent)
	_draw_regions()
	
	# Debug Info Display
	_draw_debug_info()

func _draw_regions() -> void:
	# Draw region boundaries
	for region in regions.values():
		var rect = Rect2(region.left, region.top, region.right - region.left, region.bottom - region.top)
		draw_rect(rect, Color(1, 1, 1, 0.1), false, 1.0)
		# Draw region ID at center
		var center = Vector2((region.left + region.right) / 2, (region.top + region.bottom) / 2)
		draw_string(ThemeDB.fallback_font, center, str(region.id), HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1, 1, 1, 0.3))

func _draw_debug_info() -> void:
	var x_pos = pitch_width - 10
	var y_offset = 20
	var line_height = 18
	
	# Score
	var score_text = "SCORE - Red: %d  Blue: %d" % [red_score, blue_score]
	draw_string(ThemeDB.fallback_font, Vector2(x_pos, y_offset), score_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 16, Color.WHITE)
	y_offset += line_height + 5
	
	# Red Team Info
	draw_string(ThemeDB.fallback_font, Vector2(x_pos, y_offset), "RED TEAM:", HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, Color.RED)
	y_offset += line_height
	
	var red_state = "Unknown"
	if red_team.state_machine and red_team.state_machine.current_state:
		red_state = red_team.state_machine.current_state.state_name
	draw_string(ThemeDB.fallback_font, Vector2(x_pos, y_offset), "State: %s" % red_state, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color.WHITE)
	y_offset += line_height
	
	var red_controller = "None"
	if red_team.controlling_player:
		red_controller = "Player #%d" % red_team.players.find(red_team.controlling_player)
	draw_string(ThemeDB.fallback_font, Vector2(x_pos, y_offset), "Controlling: %s" % red_controller, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color.WHITE)
	y_offset += line_height
	
	var red_supporter = "None"
	if red_team.supporting_player:
		red_supporter = "Player #%d" % red_team.players.find(red_team.supporting_player)
	draw_string(ThemeDB.fallback_font, Vector2(x_pos, y_offset), "Supporting: %s" % red_supporter, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color.WHITE)
	y_offset += line_height
	
	var red_receiver = "None"
	if red_team.receiver:
		red_receiver = "Player #%d" % red_team.players.find(red_team.receiver)
	draw_string(ThemeDB.fallback_font, Vector2(x_pos, y_offset), "Receiver: %s" % red_receiver, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color.WHITE)
	y_offset += line_height + 5
	
	# Blue Team Info
	draw_string(ThemeDB.fallback_font, Vector2(x_pos, y_offset), "BLUE TEAM:", HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, Color.BLUE)
	y_offset += line_height
	
	var blue_state = "Unknown"
	if blue_team.state_machine and blue_team.state_machine.current_state:
		blue_state = blue_team.state_machine.current_state.state_name
	draw_string(ThemeDB.fallback_font, Vector2(x_pos, y_offset), "State: %s" % blue_state, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color.WHITE)
	y_offset += line_height
	
	var blue_controller = "None"
	if blue_team.controlling_player:
		blue_controller = "Player #%d" % blue_team.players.find(blue_team.controlling_player)
	draw_string(ThemeDB.fallback_font, Vector2(x_pos, y_offset), "Controlling: %s" % blue_controller, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color.WHITE)
	y_offset += line_height
	
	var blue_supporter = "None"
	if blue_team.supporting_player:
		blue_supporter = "Player #%d" % blue_team.players.find(blue_team.supporting_player)
	draw_string(ThemeDB.fallback_font, Vector2(x_pos, y_offset), "Supporting: %s" % blue_supporter, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color.WHITE)
	y_offset += line_height
	
	var blue_receiver = "None"
	if blue_team.receiver:
		blue_receiver = "Player #%d" % blue_team.players.find(blue_team.receiver)
	draw_string(ThemeDB.fallback_font, Vector2(x_pos, y_offset), "Receiver: %s" % blue_receiver, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color.WHITE)
	y_offset += line_height + 5
	
	# Ball Info
	draw_string(ThemeDB.fallback_font, Vector2(x_pos, y_offset), "BALL:", HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, Color.YELLOW)
	y_offset += line_height
	
	var ball_owner = "None"
	if ball.owner_player:
		var team = red_team if ball.owner_player in red_team.players else blue_team
		var team_name = "Red" if team == red_team else "Blue"
		ball_owner = "%s #%d" % [team_name, team.players.find(ball.owner_player)]
	draw_string(ThemeDB.fallback_font, Vector2(x_pos, y_offset), "Owner: %s" % ball_owner, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color.WHITE)
	y_offset += line_height
	
	var ball_speed = ball.linear_velocity.length()
	draw_string(ThemeDB.fallback_font, Vector2(x_pos, y_offset), "Speed: %.1f" % ball_speed, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color.WHITE)
	y_offset += line_height
	
	# Control Info
	var control_team = "None"
	if controlling_team:
		control_team = "Red" if controlling_team == red_team else "Blue"
	draw_string(ThemeDB.fallback_font, Vector2(x_pos, y_offset), "Control: %s" % control_team, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color.WHITE)

func _update_ball_control(delta: float) -> void:
	# Find closest player to ball from BOTH teams
	var closest_player: PlayerBase = null
	var closest_dist_sq = INF
	var closest_team: Node2D = null
	
	# Check red team
	for p in red_team.players:
		var dist_sq = p.global_position.distance_squared_to(ball.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest_player = p
			closest_team = red_team
	
	# Check blue team
	for p in blue_team.players:
		var dist_sq = p.global_position.distance_squared_to(ball.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest_player = p
			closest_team = blue_team
	
	# Control threshold
	var control_threshold_sq = 20.0 * 20.0
	var closest_dist = sqrt(closest_dist_sq)
	
	# Determine if anyone should have control
	if closest_player and closest_dist_sq < control_threshold_sq:
		print("[BALL] Closest player: %s P%d (dist: %.1f)" % [closest_team.name, closest_team.players.find(closest_player), closest_dist])
		# Check cooldown to prevent rapid switching
		var time_since_change = Time.get_ticks_msec() / 1000.0 - control_changed_time
		
		# If no one has control OR cooldown expired OR same team trying to maintain control
		if controlling_team == null or time_since_change >= CONTROL_CHANGE_COOLDOWN or controlling_team == closest_team:
			# If control is changing teams
			if controlling_team != closest_team:
				# Clear old team's control
				if controlling_team != null:
					print("[CONTROL] %s LOST ball control" % controlling_team.name)
					controlling_team.controlling_player = null
				
				controlling_team = closest_team
				control_changed_time = Time.get_ticks_msec() / 1000.0
				print("[CONTROL] %s GAINED ball control (P%d)" % [controlling_team.name, controlling_team.players.find(closest_player)])
			
			# Update team's controlling_player
			closest_team.controlling_player = closest_player
			ball.owner_player = closest_player
	else:
		# No one close enough - clear control from both teams
		if controlling_team:
			controlling_team.controlling_player = null
			ball.owner_player = null
		
		# Clear both teams to be safe
		red_team.controlling_player = null
		blue_team.controlling_player = null
		controlling_team = null
