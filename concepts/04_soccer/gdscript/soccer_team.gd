class_name SoccerTeam extends Node2D

enum TeamColor { RED, BLUE }

var color: TeamColor
var players: Array[PlayerBase] = []
var pitch: SoccerPitch
var home_goal: Goal
var opponents_goal: Goal

# Tactical
var controlling_player: PlayerBase = null
var supporting_player: PlayerBase = null
var receiver: PlayerBase = null
var closest_player_to_ball: PlayerBase = null

func _init(p_pitch: SoccerPitch, p_color: TeamColor, p_home_goal: Goal, p_opponents_goal: Goal) -> void:
	pitch = p_pitch
	color = p_color
	home_goal = p_home_goal
	opponents_goal = p_opponents_goal

func _ready() -> void:
	_create_players()

func _create_players() -> void:
	# 1 Goalkeeper + 4 Field Players
	# Regions setup: 
	# 0 1 2 3
	# 4 5 6 7
	# 8 9 10 11
	
	if color == TeamColor.RED:
		# Red defends Left (regions 0, 4, 8, 1, 5, 9)
		# Keeper
		_add_player(Goalkeeper, 4) # Middle left
		# Field
		_add_player(FieldPlayer, 1) # Top def
		_add_player(FieldPlayer, 9) # Bottom def
		_add_player(FieldPlayer, 6) # Mid
		_add_player(FieldPlayer, 7) # Forward
	else:
		# Blue defends Right
		# Keeper
		_add_player(Goalkeeper, 7) # Middle right
		# Field
		_add_player(FieldPlayer, 2) # Top def
		_add_player(FieldPlayer, 10) # Bottom def
		_add_player(FieldPlayer, 5) # Mid
		_add_player(FieldPlayer, 4) # Forward (relative to their side)

func _add_player(type, region_id: int) -> void:
	var p = type.new(self, region_id, 70.0, 150.0, 100.0, 5.0)
	p.position = pitch.regions[region_id].center
	
	# Visuals
	var sprite = Sprite2D.new()
	sprite.texture = load("res://icon.svg")
	sprite.scale = Vector2(0.3, 0.3)
	if color == TeamColor.RED:
		sprite.modulate = Color.RED
	else:
		sprite.modulate = Color.BLUE
	p.add_child(sprite)
	
	players.append(p)
	add_child(p)

func _process(_delta: float) -> void:
	_update_closest_player_to_ball()
	_check_ball_control()

func _update_closest_player_to_ball() -> void:
	var closest_dist = INF
	closest_player_to_ball = null
	
	for p in players:
		var d = p.global_position.distance_squared_to(pitch.ball.global_position)
		if d < closest_dist:
			closest_dist = d
			closest_player_to_ball = p

func _check_ball_control() -> void:
	controlling_player = null
	var dist_threshold = 20.0 * 20.0
	
	# Simple check: if closest is close enough, they control it
	if closest_player_to_ball:
		if closest_player_to_ball.global_position.distance_squared_to(pitch.ball.global_position) < dist_threshold:
			controlling_player = closest_player_to_ball
			pitch.ball.owner_player = controlling_player
			pitch.ball.trap() # Stop ball so they can dribble/kick
