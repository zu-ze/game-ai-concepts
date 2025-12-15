class_name SoccerTeam extends Node2D

enum TeamColor { RED, BLUE }

var color: TeamColor
var players: Array[PlayerBase] = []
var pitch: Node2D # Weakly typed to avoid cyclic dependency loop
var home_goal: Goal
var opponents_goal: Goal

var state_machine: StateMachine
var support_spot_calculator: SupportSpotCalculator

# Tactical
var controlling_player: PlayerBase = null
var supporting_player: PlayerBase = null
var receiver: PlayerBase = null
var closest_player_to_ball: PlayerBase = null

func _init(p_pitch: Node2D, p_color: TeamColor, p_home_goal: Goal, p_opponents_goal: Goal) -> void:
	pitch = p_pitch
	color = p_color
	home_goal = p_home_goal
	opponents_goal = p_opponents_goal
	support_spot_calculator = SupportSpotCalculator.new(self)

func _ready() -> void:
	state_machine = StateMachine.new(self)
	_create_players()
	# Start in PrepareForKickOff, Red team gets the kickoff
	state_machine.set_current_state(PrepareForKickOff.new(TeamColor.RED))

func _create_players() -> void:
	# 1 Goalkeeper + 4 Field Players
	# Regions setup (8 cols x 3 rows): 
	# 0  1  2  3  4  5  6  7
	# 8  9 10 11 12 13 14 15
	# 16 17 18 19 20 21 22 23
	# Midfield is between columns 3 and 4
	
	if color == TeamColor.RED:
		# Red defends Left (columns 0-3)
		# Keeper
		_add_player(Goalkeeper, 8) # Column 0, middle
		# Field - keep all on left side initially
		_add_player(FieldPlayer, 1) # Column 1, top
		_add_player(FieldPlayer, 17) # Column 1, bottom
		_add_player(FieldPlayer, 10) # Column 2, middle
		_add_player(FieldPlayer, 11) # Column 3, middle (at midfield)
	else:
		# Blue defends Right (columns 4-7)
		# Keeper
		_add_player(Goalkeeper, 15) # Column 7, middle
		# Field - keep all on right side initially
		_add_player(FieldPlayer, 6) # Column 6, top
		_add_player(FieldPlayer, 22) # Column 6, bottom
		_add_player(FieldPlayer, 13) # Column 5, middle
		_add_player(FieldPlayer, 12) # Column 4, middle (at midfield)

func _add_player(type, region_id: int) -> void:
	# Add speed variation (±10% randomization)
	var base_max_speed = 450.0 + randf_range(-45.0, 45.0)
	var base_max_force = 300.0 + randf_range(-30.0, 30.0)
	var p = type.new(self, region_id, 70.0, base_max_speed, base_max_force, 5.0)
	p.position = pitch.regions[region_id].center
	print("[%s] Created player type=%s region=%d speed=%.1f force=%.1f" % [name, type, region_id, base_max_speed, base_max_force])
	
	# Physics layers
	# Layer 1: Walls
	# Layer 2: Ball
	# Layer 3: Players
	p.collision_layer = 4  # Layer 3: Players
	p.collision_mask = 1   # Collide with walls only
	
	# Collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = p.bounding_radius
	collision.shape = shape
	p.add_child(collision)
	
	# Visuals
	var sprite = Sprite2D.new()
	sprite.texture = load("res://player.png")
	sprite.scale = Vector2(0.25, 0.25)
	
	# Color based on type and team
	if type == Goalkeeper:
		if color == TeamColor.RED:
			sprite.modulate = Color.ORANGE_RED
		else:
			sprite.modulate = Color.CYAN
	else:
		if color == TeamColor.RED:
			sprite.modulate = Color.RED
		else:
			sprite.modulate = Color.BLUE
	p.add_child(sprite)
	
	players.append(p)
	add_child(p)

func _process(_delta: float) -> void:
	_update_closest_player_to_ball()
	# Ball control is now managed by pitch authoritatively
	state_machine.update()
	_update_support_spot()
	queue_redraw() # For debug labels

func _update_support_spot() -> void:
	# Only calculate if we are attacking (have control)
	if controlling_player:
		var best_spot = support_spot_calculator.determine_best_supporting_spot()
		_determine_supporting_player(best_spot)
	else:
		supporting_player = null

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
	
	# Draw player labels for debugging
	for i in range(players.size()):
		var p = players[i]
		var label = ""
		
		# Player type
		if p is Goalkeeper:
			label = "GK"
		else:
			label = "P%d" % i
		
		# Player state/role indicators
		if p == controlling_player:
			label += " [CTRL]"
		elif p == supporting_player:
			label += " [SUP]"
		elif p == receiver:
			label += " [RCV]"
		elif p == closest_player_to_ball:
			label += " [NEAR]"
		
		# Draw label above player
		var label_pos = p.global_position - Vector2(0, 25)
		var label_color = Color.RED if color == TeamColor.RED else Color.BLUE
		if p is Goalkeeper:
			label_color = Color.ORANGE_RED if color == TeamColor.RED else Color.CYAN
		
		draw_string(ThemeDB.fallback_font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, label_color)

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
	var center_safe = is_pass_safe_from_all_opponents(from, opponents_goal.center, null, power)
	if center_safe:
		result.can_shoot = true
		result.target = opponents_goal.center
		print("[%s] CAN SHOOT at center from %v!" % [name, from])
		return result
		
	# Sample along goal line
	for i in range(num_samples):
		var t = randf()
		var target = opponents_goal.left_post.lerp(opponents_goal.right_post, t)
		var safe = is_pass_safe_from_all_opponents(from, target, null, power)
		
		if safe:
			result.can_shoot = true
			result.target = target
			print("[%s] CAN SHOOT at sample %d from %v!" % [name, i, from])
			return result # Return first valid for now
			
	return result

func find_pass(passer: PlayerBase, power: float, min_passing_dist: float = 50.0) -> Dictionary:
	# Returns { "success": bool, "receiver": PlayerBase, "target": Vector2 }
	var best_result = { "success": false, "receiver": null, "target": Vector2.ZERO }
	var best_score = -1.0
	
	for p in players:
		if p == passer: continue
		
		var dist = passer.global_position.distance_to(p.global_position)
		if dist < min_passing_dist: 
			continue
		
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
	
	if best_result.success:
		print("[%s] PASS FOUND to P%d!" % [name, players.find(best_result.receiver)])
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

func set_player_home_region(player_idx: int, region_id: int) -> void:
	if player_idx >= 0 and player_idx < players.size():
		players[player_idx].home_region = region_id

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
# State classes are defined here to access SoccerTeam methods, 
# but since they are inner classes in GDScript, they access outer scope variables naturally in Godot 4.
# However, passing 'entity' (which is the team) is still the pattern we used.
# The issue "Invalid call. Nonexistent function" usually means the entity passed is not cast correctly or the function is truly missing.
# We just re-added set_player_home_region, so it should be there.
# The error might be from a previous run if the user didn't reload or if the script wasn't saved properly?
# Let's double check if I made a mistake in where I added the function.
# It is added before "return_all_field_players_to_home". It looks correct.

# Wait, in GDScript inner classes, they are just classes. They don't automatically have access to "outer" instance unless passed.
# We are passing 'entity' as 'SoccerTeam'.
# So `team.set_player_home_region` should work if `team` is `SoccerTeam`.

# To be absolutely safe and clean, I will leave the structure as is, 
# as I just added the missing function.

class PrepareForKickOff extends State:
	var kick_off_team: SoccerTeam.TeamColor
	
	func _init(p_kick_off_team: SoccerTeam.TeamColor = SoccerTeam.TeamColor.RED) -> void:
		state_name = "PrepareForKickOff"
		kick_off_team = p_kick_off_team
	
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
		if team.all_players_at_home():
			# Team that kicks off goes to Attacking, other team to Defending
			if team.color == kick_off_team:
				team.state_machine.change_state(TeamAttacking.new())
			else:
				team.state_machine.change_state(TeamDefending.new())

	func exit(entity: Node) -> void:
		pass

class TeamDefending extends State:
	func _init() -> void:
		state_name = "TeamDefending"
	
	func enter(entity: Node) -> void:
		var team = entity as SoccerTeam
		print(team.name, " entering Defending state")
		
		# Set defending regions - stay on own side
		# 0  1  2  3  4  5  6  7
		# 8  9 10 11 12 13 14 15
		# 16 17 18 19 20 21 22 23
		
		if team.color == SoccerTeam.TeamColor.RED:
			# Defending Left (columns 0-3)
			team.set_player_home_region(1, 1) # Top def
			team.set_player_home_region(2, 17) # Bottom def
			team.set_player_home_region(3, 10) # Mid
			team.set_player_home_region(4, 11) # Forward at midfield
		else:
			# Defending Right (columns 4-7)
			team.set_player_home_region(1, 6) # Top def
			team.set_player_home_region(2, 22) # Bottom def
			team.set_player_home_region(3, 13) # Mid
			team.set_player_home_region(4, 12) # Forward at midfield
			
	func execute(entity: Node) -> void:
		var team = entity as SoccerTeam
		if team.controlling_player != null:
			team.state_machine.change_state(TeamAttacking.new())

	func exit(entity: Node) -> void:
		pass

class TeamAttacking extends State:
	func _init() -> void:
		state_name = "TeamAttacking"
	
	func enter(entity: Node) -> void:
		var team = entity as SoccerTeam
		print(team.name, " entering Attacking state")
		
		if team.color == SoccerTeam.TeamColor.RED:
			# Attacking Right (push into columns 4-5)
			team.set_player_home_region(1, 2) # Top def stays back
			team.set_player_home_region(2, 18) # Bottom def stays back
			team.set_player_home_region(3, 11) # Mid at midfield
			team.set_player_home_region(4, 13) # Forward pushes into opponent half
		else:
			# Attacking Left (push into columns 2-3)
			team.set_player_home_region(1, 5) # Top def stays back
			team.set_player_home_region(2, 21) # Bottom def stays back
			team.set_player_home_region(3, 12) # Mid at midfield
			team.set_player_home_region(4, 10) # Forward pushes into opponent half

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
