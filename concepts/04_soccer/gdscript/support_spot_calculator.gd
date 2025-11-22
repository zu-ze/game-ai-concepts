class_name SupportSpotCalculator extends RefCounted

var team: SoccerTeam
var best_supporting_spot: Vector2 = Vector2.ZERO
var best_supporting_spot_score: float = 0.0

# Config
var spot_can_pass_score: float = 2.0
var spot_can_score_from_position_score: float = 1.0
var optimal_distance: float = 200.0
var dist_score_factor: float = 1.0 # Multiplier for distance score component

# Spots to sample
var spots: Array[Vector2] = []

func _init(p_team: SoccerTeam) -> void:
	team = p_team
	_generate_spots()

func _generate_spots() -> void:
	# Generate a grid of spots in the pitch
	# In a real game, maybe only sample relevant areas. 
	# Here we sample the whole pitch but score them.
	# Or as text says "opponent's half". But that changes based on L/R.
	# We'll sample the whole pitch grid (e.g. 10x6)
	var cols = 12
	var rows = 7
	var step_x = team.pitch.pitch_width / cols
	var step_y = team.pitch.pitch_height / rows
	
	for y in range(1, rows):
		for x in range(1, cols):
			spots.append(Vector2(x * step_x, y * step_y))

func determine_best_supporting_spot() -> Vector2:
	best_supporting_spot = Vector2.ZERO
	best_supporting_spot_score = -1.0
	
	var controlling = team.controlling_player
	if not controlling:
		return Vector2.ZERO
		
	for spot in spots:
		var score = _calculate_score(spot, controlling)
		if score > best_supporting_spot_score:
			best_supporting_spot_score = score
			best_supporting_spot = spot
			
	return best_supporting_spot

func _calculate_score(spot: Vector2, controlling_player: PlayerBase) -> float:
	var score = 0.0
	
	# 1. Passing Potential (Safe to pass?)
	if _is_safe_to_pass(controlling_player.global_position, spot):
		score += spot_can_pass_score
	else:
		return 0.0 # If can't pass, it's useless
		
	# 2. Goal Shot Potential
	if _can_score(spot):
		score += spot_can_score_from_position_score
		
	# 3. Optimal Distance
	var dist = controlling_player.global_position.distance_to(spot)
	var dist_diff = abs(dist - optimal_distance)
	# Normalize or curve this score? 
	# Simple linear penalty for being away from optimal
	# Max score if distance is perfect.
	# Assuming max pitch dimension ~1000.
	if dist_diff < optimal_distance:
		score += (optimal_distance - dist_diff) / optimal_distance
		
	# 4. Bonus: Upfield?
	# Supporting spot should be "farther upfield from the attacker"
	var is_upfield = false
	if team.color == SoccerTeam.TeamColor.RED:
		# Attacking Right. Spot.x > Player.x
		is_upfield = spot.x > controlling_player.global_position.x
	else:
		# Attacking Left. Spot.x < Player.x
		is_upfield = spot.x < controlling_player.global_position.x
		
	if is_upfield:
		score += 1.0
		
	return score

func _is_safe_to_pass(from: Vector2, to: Vector2) -> bool:
	# Check if any opponent intersects the ray with a buffer
	var ray_dir = (to - from).normalized()
	var ray_len = from.distance_to(to)
	var opponents = team.pitch.blue_team.players if team.color == SoccerTeam.TeamColor.RED else team.pitch.red_team.players
	
	for opp in opponents:
		# Simplified: Project opponent pos onto ray
		var to_opp = opp.global_position - from
		var projection = to_opp.dot(ray_dir)
		
		if projection > 0 and projection < ray_len:
			# Opponent is roughly alongside the path
			var perp_dist = (to_opp - ray_dir * projection).length()
			# If close enough to intercept
			if perp_dist < 40.0: # Interception range
				return false
				
	return true

func _can_score(from: Vector2) -> bool:
	# Check if clear shot to goal
	var goal = team.opponents_goal
	return _is_safe_to_pass(from, goal.center)
