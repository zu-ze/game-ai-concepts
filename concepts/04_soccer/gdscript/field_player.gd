class_name FieldPlayer extends PlayerBase

# States
var global_state: State
var motion_state: State

func _ready() -> void:
	super._ready()
	# Setup FSM
	# Using the same StateMachine we built in concept 02
	# Need to ensure we import/load those classes or they are globally available.
	# Assuming global classes from concept 02 are available (BaseGameEntity uses StateMachine)
	
	# Note: We might need a specific FieldPlayerStateMachine if we want separate Global/Current logic
	# But our generic StateMachine supports Global and Current.
	
	state_machine.set_current_state(Wait.new())
	state_machine.set_global_state(FieldPlayerGlobalState.new())

func handle_message(telegram: Telegram) -> bool:
	return state_machine.handle_message(telegram)

# States ---------------------------------------------------------

class FieldPlayerGlobalState extends State:
	func execute(entity: Node) -> void:
		# Global logic, e.g. check if game is paused
		pass
		
	func on_message(entity: Node, telegram: Telegram) -> bool:
		# Handle global messages like "ReturnToHome" or "ReceiveBall"
		return false

class Wait extends State:
	func enter(entity: Node) -> void:
		entity.velocity = Vector2.ZERO
		# entity.steering.active = false (if we had an active flag)
		entity.get_steering().flags = 0 # Disable all steering
		
	func execute(entity: Node) -> void:
		if entity.is_closest_team_member_to_ball() and \
		   entity.team.receiver != entity and \
		   not entity.team.pitch.ball.owner_player:
			entity.state_machine.change_state(ChaseBall.new())
		
		# If not chasing, maybe return to region home?
		# simplified
	
	func exit(entity: Node) -> void:
		pass

class ChaseBall extends State:
	func enter(entity: Node) -> void:
		entity.get_steering().flags = SteeringBehaviors.BehaviorType.SEEK
		
	func execute(entity: Node) -> void:
		entity.get_steering().target_pos = entity.team.pitch.ball.position
		
		if entity.is_controlling_ball():
			entity.state_machine.change_state(KickBall.new())
			return
			
		if not entity.is_closest_team_member_to_ball():
			entity.state_machine.change_state(ReturnToHome.new())

	func exit(entity: Node) -> void:
		entity.get_steering().flags = 0

class KickBall extends State:
	func enter(entity: Node) -> void:
		entity.velocity = Vector2.ZERO
		
	func execute(entity: Node) -> void:
		# Decide where to kick
		# Simple: Kick towards goal
		var target = entity.team.opponents_goal.center
		
		# Add randomness/noise
		
		entity.team.pitch.ball.kick(target - entity.global_position, 200.0)
		entity.state_machine.change_state(Wait.new())

	func exit(entity: Node) -> void:
		pass

class ReturnToHome extends State:
	func enter(entity: Node) -> void:
		entity.get_steering().flags = SteeringBehaviors.BehaviorType.ARRIVE
		
	func execute(entity: Node) -> void:
		var region = entity.team.pitch.regions[entity.home_region]
		entity.get_steering().target_pos = region.center
		
		if entity.is_closest_team_member_to_ball() and not entity.team.pitch.ball.owner_player:
			entity.state_machine.change_state(ChaseBall.new())
			return
			
		if entity.global_position.distance_squared_to(region.center) < 100:
			entity.state_machine.change_state(Wait.new())

	func exit(entity: Node) -> void:
		entity.get_steering().flags = 0
