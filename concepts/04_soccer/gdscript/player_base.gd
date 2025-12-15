class_name PlayerBase extends Vehicle

var team: SoccerTeam
var home_region: int
var default_region: int
var _last_pos_debug: Vector2 = Vector2.ZERO
var _debug_timer: float = 0.0
var last_dribble_time: float = 0.0  # Track when last dribble occurred

func _init(p_team: SoccerTeam, p_home_region: int, p_mass: float, p_max_speed: float, p_max_force: float, p_max_turn_rate: float) -> void:
	super._init() # Vehicle init
	team = p_team
	home_region = p_home_region
	default_region = p_home_region
	mass = p_mass
	max_speed = p_max_speed
	max_force = p_max_force
	max_turn_rate = p_max_turn_rate

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Debug position/velocity every 3 seconds (reduced spam)
	_debug_timer += delta
	if _debug_timer >= 3.0:
		_debug_timer = 0.0
		var player_idx = team.players.find(self)
		var moved = global_position.distance_to(_last_pos_debug)
		var state_name_str = "Unknown"
		if state_machine and state_machine.current_state:
			state_name_str = state_machine.current_state.state_name
		print("[%s P%d] Pos: %v, Vel: %v (%.1f), Moved: %.1f, State: %s" % [
			team.name, player_idx, global_position, velocity, velocity.length(), moved, state_name_str
		])
		_last_pos_debug = global_position

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
