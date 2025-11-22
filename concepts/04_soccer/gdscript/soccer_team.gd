class_name SoccerTeam extends Node2D

enum TeamColor { RED, BLUE }

var color: TeamColor
var players: Array[PlayerBase] = []
var pitch: SoccerPitch
var home_goal: Goal
var opponents_goal: Goal

var state_machine: StateMachine
var support_spot_calculator: SupportSpotCalculator

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
	support_spot_calculator = SupportSpotCalculator.new(self)

func _ready() -> void:
	state_machine = StateMachine.new(self)
	_create_players()
	# Start in PrepareForKickOff to align positions initially
	state_machine.set_current_state(PrepareForKickOff.new())

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
	state_machine.update()
	_update_support_spot()

func _update_support_spot() -> void:
	# Only calculate if we are attacking (have control)
	if controlling_player:
		var best_spot = support_spot_calculator.determine_best_supporting_spot()
		_determine_supporting_player(best_spot)
		queue_redraw() # Debug viz
	else:
		supporting_player = null
		queue_redraw()

func _determine_supporting_player(best_spot: Vector2) -> void:
	var closest_dist = INF
	var best_player: PlayerBase = null
	
	for p in players:
		# Only field players, not the controller, not the receiver (if assigned)
		if p is FieldPlayer and p != controlling_player:
			var d = p.global_position.distance_squared_to(best_spot)
			if d < closest_dist:
				closest_dist = d
				best_player = p
				
	supporting_player = best_player

func _draw() -> void:
	if supporting_player:
		draw_circle(support_spot_calculator.best_supporting_spot, 10.0, Color.YELLOW)
		draw_line(supporting_player.global_position, support_spot_calculator.best_supporting_spot, Color.YELLOW, 1.0, true)

func _update_closest_player_to_ball() -> void:
	var closest_dist = INF
	closest_player_to_ball = null
	
	for p in players:
		var d = p.global_position.distance_squared_to(pitch.ball.global_position)
		if d < closest_dist:
			closest_dist = d
			closest_player_to_ball = p

func is_pass_safe_from_all_opponents(from: Vector2, to: Vector2, receiver_player: PlayerBase = null, pass_force: float = 200.0) -> bool:
	var ray_dir = (to - from).normalized()
	var ray_len = from.distance_to(to)
	var opponents = pitch.blue_team.players if color == TeamColor.RED else pitch.red_team.players
	
	# Local coordinates frame: X is RayDir, Y is Orthogonal
	var local_x = ray_dir
	var local_y = ray_dir.orthogonal()
	
	for opp in opponents:
		var to_opp = opp.global_position - from
		var opp_local_x = to_opp.dot(local_x)
		var opp_local_y = to_opp.dot(local_y)
		
		# 1. Check if behind passer
		if opp_local_x < 0:
			continue
			
		# 2. Check if opponent is too far ahead (beyond target)
		# (Optional optimization, but text focuses on intercept)
		
		# 3. Intercept Check
		# Ball time to intercept point (which is at dist opp_local_x along ray)
		# The intercept point on the line is 'from + ray_dir * opp_local_x'
		# We use the ball's time_to_cover_distance method.
		
		# We need the start velocity 'u' from force. 
		# In SoccerBall logic: u = force / mass.
		# We assume standard ball mass 1.0 for simplicity or use pitch.ball.mass if available.
		# pitch.ball.time_to_cover_distance uses this logic.
		
		# intercept point is 'opp_local_x' away from 'from'.
		# Construct a point
		var intercept_point = from + ray_dir * opp_local_x
		var t_ball = pitch.ball.time_to_cover_distance(from, intercept_point, pass_force)
		
		if t_ball < 0: 
			# Ball can't reach there (friction)
			# Effectively safe from this opponent regarding interception at this point, 
			# but maybe ball stops short? If pass target is further, pass fails anyway.
			continue
			
		# Opponent Reach
		# Reach = (Opp Max Speed * t_ball) + BallRadius + OppRadius
		var ball_radius = 5.0 # pitch.ball.bounding_radius if exists
		var opp_radius = opp.bounding_radius
		var reach = (opp.max_speed * t_ball) + ball_radius + opp_radius
		
		# Check if opponent can reach the line
		if abs(opp_local_y) < reach:
			return false # Intercepted
			
	return true

func can_shoot(from: Vector2, power: float) -> Dictionary:
	# Returns { "can_shoot": bool, "target": Vector2 }
	var result = { "can_shoot": false, "target": Vector2.ZERO }
	
	# Randomly sample points along the opponent's goal mouth
	# Goal defined by left_post and right_post
	var num_samples = 5
	var best_target = Vector2.ZERO
	
	# Check center first
	if is_pass_safe_from_all_opponents(from, opponents_goal.center, null, power):
		result.can_shoot = true
		result.target = opponents_goal.center
		return result
		
	# Sample along goal line
	for i in range(num_samples):
		var t = randf()
		var target = opponents_goal.left_post.lerp(opponents_goal.right_post, t)
		
		if is_pass_safe_from_all_opponents(from, target, null, power):
			result.can_shoot = true
			result.target = target
			return result # Return first valid for now
			
	return result

func find_pass(passer: PlayerBase, power: float, min_passing_dist: float = 50.0) -> Dictionary:
	# Returns { "success": bool, "receiver": PlayerBase, "target": Vector2 }
	var best_result = { "success": false, "receiver": null, "target": Vector2.ZERO }
	var best_score = -1.0
	
	for p in players:
		if p == passer: continue
		
		var dist = passer.global_position.distance_to(p.global_position)
		if dist < min_passing_dist: continue
		
		var pass_info = get_best_pass_to_receiver(passer, p, power)
		if pass_info.success:
			# Score based on closeness to opponent goal
			var score = pitch.pitch_width - pass_info.target.distance_to(opponents_goal.center) # Crude
			# Or strictly x-coordinate advancement
			if color == TeamColor.RED: score = pass_info.target.x
			else: score = pitch.pitch_width - pass_info.target.x
			
			if score > best_score:
				best_score = score
				best_result = pass_info
				best_result["receiver"] = p
				
	return best_result

func get_best_pass_to_receiver(passer: PlayerBase, receiver: PlayerBase, power: float) -> Dictionary:
	# Sample around receiver
	var samples = [receiver.global_position]
	# Add some offset samples? e.g. slightly ahead
	# For now, just check direct position
	
	for target in samples:
		if is_pass_safe_from_all_opponents(passer.global_position, target, receiver, power):
			return { "success": true, "target": target }
			
	return { "success": false, "target": Vector2.ZERO }

func request_pass(requester: PlayerBase) -> void:
	# If controlling player exists and is not requester
	if controlling_player and controlling_player != requester:
		# Send message to controlling player to pass to me
		# But wait, the text says requester sends Msg_PassToMe to controlling player?
		# Or controlling player logic handles it?
		# "The player attempts to make a safe pass to the requesting player"
		# So requester sends msg to controller.
		MessageDispatcher.dispatch_message(0, requester, controlling_player, MessageTypes.MSG_PASS_TO_ME)

func get_support_spot() -> Vector2:
	return support_spot_calculator.best_supporting_spot

func _check_ball_control() -> void:
	controlling_player = null
	var dist_threshold = 20.0 * 20.0
	
	# Simple check: if closest is close enough, they control it
	if closest_player_to_ball:
		if closest_player_to_ball.global_position.distance_squared_to(pitch.ball.global_position) < dist_threshold:
			controlling_player = closest_player_to_ball
			pitch.ball.owner_player = controlling_player
			pitch.ball.trap() # Stop ball so they can dribble/kick

func update_targets_of_waiting_players() -> void:
	for p in players:
		if p is FieldPlayer:
			if p.state_machine.is_in_state(p.state_machine.current_state): # Simplify check, assuming logic inside State handles target update
				# Actually, if they are in Wait or ReturnToHome, we just need to ensure 
				# their steering target is updated to the NEW home region center.
				# The ReturnToHome state in FieldPlayer constantly updates target to home_region center.
				# The Wait state sets velocity to zero.
				# If we want them to move to new home immediately, we should message them "GoHome".
				pass

func return_all_field_players_to_home() -> void:
	for p in players:
		if p is FieldPlayer:
			MessageDispatcher.dispatch_message(0, self, p, MessageTypes.MSG_GO_HOME)

func all_players_at_home() -> bool:
	for p in players:
		if p is FieldPlayer:
			var home_pos = pitch.regions[p.home_region].center
			if p.global_position.distance_squared_to(home_pos) > 1000: # Tolerance
				return false
	return true

# States ---------------------------------------------------------

class PrepareForKickOff extends State:
	func enter(entity: Node) -> void:
		var team = entity as SoccerTeam
		print(team.name, " entering PrepareForKickOff state")
		
		team.controlling_player = null
		team.supporting_player = null
		team.receiver = null
		team.closest_player_to_ball = null
		
		team.return_all_field_players_to_home()
		
	func execute(entity: Node) -> void:
		var team = entity as SoccerTeam
		# Check if both teams are home
		# For this simplified logic, just check this team
		if team.all_players_at_home(): # AND opponent team is at home...
			team.state_machine.change_state(TeamDefending.new())

	func exit(entity: Node) -> void:
		pass

class TeamDefending extends State:
	func enter(entity: Node) -> void:
		var team = entity as SoccerTeam
		print(team.name, " entering Defending state")
		
		# Set defending regions
		# 0 1 2 3
		# 4 5 6 7
		# 8 9 10 11
		
		if team.color == SoccerTeam.TeamColor.RED:
			# Defending Left
			team.set_player_home_region(1, 1) # Top def
			team.set_player_home_region(2, 9) # Bottom def
			team.set_player_home_region(3, 5) # Mid
			team.set_player_home_region(4, 6) # Fwd (pulled back)
		else:
			# Defending Right
			team.set_player_home_region(1, 2)
			team.set_player_home_region(2, 10)
			team.set_player_home_region(3, 6)
			team.set_player_home_region(4, 5)
			
	func execute(entity: Node) -> void:
		var team = entity as SoccerTeam
		if team.controlling_player != null:
			team.state_machine.change_state(TeamAttacking.new())

	func exit(entity: Node) -> void:
		pass

class TeamAttacking extends State:
	func enter(entity: Node) -> void:
		var team = entity as SoccerTeam
		print(team.name, " entering Attacking state")
		
		if team.color == SoccerTeam.TeamColor.RED:
			# Attacking Right
			team.set_player_home_region(1, 5) # Top def moves up
			team.set_player_home_region(2, 8) # Bottom def stays back a bit?
			team.set_player_home_region(3, 6) # Mid moves up
			team.set_player_home_region(4, 7) # Fwd pushes deep
		else:
			# Attacking Left
			team.set_player_home_region(1, 6)
			team.set_player_home_region(2, 3)
			team.set_player_home_region(3, 5)
			team.set_player_home_region(4, 4)

	func execute(entity: Node) -> void:
		var team = entity as SoccerTeam
		# If we lose control, defend
		if team.controlling_player == null:
			# Should check if opponent has control to switch? 
			# Or just if we don't have it?
			# For simple soccer, if we don't have it, we defend.
			team.state_machine.change_state(TeamDefending.new())
			
	func exit(entity: Node) -> void:
		pass
