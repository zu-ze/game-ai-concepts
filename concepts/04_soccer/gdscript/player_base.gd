class_name PlayerBase extends Vehicle

var team: SoccerTeam
var home_region: int
var default_region: int

func _init(p_team: SoccerTeam, p_home_region: int, p_mass: float, p_max_speed: float, p_max_force: float, p_max_turn_rate: float) -> void:
	super._init() # Vehicle init
	team = p_team
	home_region = p_home_region
	default_region = p_home_region
	mass = p_mass
	max_speed = p_max_speed
	max_force = p_max_force
	max_turn_rate = p_max_turn_rate

func is_closest_team_member_to_ball() -> bool:
	return team.closest_player_to_ball == self

func is_controlling_ball() -> bool:
	return team.controlling_player == self

func is_threatened() -> bool:
	# Check against all opponents
	# If any opponent is within a comfort radius, return true
	var opponents = team.pitch.blue_team.players if team.color == SoccerTeam.TeamColor.RED else team.pitch.red_team.players
	var comfort_radius_sq = 50.0 * 50.0 # Arbitrary distance
	
	for opp in opponents:
		if global_position.distance_squared_to(opp.global_position) < comfort_radius_sq:
			return true
	return false
