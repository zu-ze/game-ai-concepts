class_name Goalkeeper extends PlayerBase

var look_at_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	state_machine.set_current_state(TendGoal.new())
	state_machine.set_global_state(GlobalKeeperState.new())

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# Goalkeeper always looks at ball
	if team and team.pitch and team.pitch.ball:
		look_at_pos = team.pitch.ball.global_position
		rotation = (look_at_pos - global_position).angle()

func handle_message(telegram: Telegram) -> bool:
	return state_machine.handle_message(telegram)

# States ---------------------------------------------------------

class GlobalKeeperState extends State:
	func execute(entity: Node) -> void:
		pass
		
	func on_message(entity: Node, telegram: Telegram) -> bool:
		if telegram.msg == MessageTypes.MSG_GO_HOME:
			entity.get_steering().target_pos = entity.team.pitch.regions[entity.home_region].center
			entity.state_machine.change_state(ReturnHome.new())
			return true
		elif telegram.msg == MessageTypes.MSG_RECEIVE_BALL:
			entity.state_machine.change_state(InterceptBall.new())
			return true
		return false

class TendGoal extends State:
	func enter(entity: Node) -> void:
		entity.get_steering().interpose_on()
		# Tend distance handled in execute?
		# Or we simulate Interpose by setting target agents?
		# Standard Interpose uses 2 agents. Here we interpose Ball and RearTarget.
		# We need a dummy vehicle for rear target or adapt steering.
		# For simplicity, we'll calculate the target manually and use Arrive, 
		# effectively mimicking the result of "Interpose" described.
		entity.get_steering().interpose_off() # Use Manual Arrive
		entity.get_steering().arrive_on()
		
	func execute(entity: Node) -> void:
		var ball = entity.team.pitch.ball
		var goal_center = entity.team.home_goal.center
		
		# Calculate Rear Target along goal line
		# Proportional to ball Y
		# If ball is high, target is high.
		var ball_y_relative = ball.global_position.y - (entity.team.pitch.pitch_height/2.0)
		var target_y = (entity.team.pitch.pitch_height/2.0) + ball_y_relative
		
		# Clamp to goal width
		target_y = clamp(target_y, entity.team.home_goal.left_post.y, entity.team.home_goal.right_post.y)
		var target_x = goal_center.x + (entity.team.home_goal.facing_direction.x * 20.0) # Slightly in front
		
		var rear_target = Vector2(target_x, target_y)
		
		# Move to point between ball and rear_target
		# The "Interpose" behavior usually picks the midpoint.
		var interpose_pos = (ball.global_position + rear_target) / 2.0
		
		# But constrained to be near goal
		# Let's just arrive at the rear_target directly for simple tending, 
		# or slightly ahead of it.
		entity.get_steering().target_pos = rear_target
		
		# Check intercept
		if ball.global_position.distance_squared_to(entity.global_position) < 4000: # 60^2
			entity.state_machine.change_state(InterceptBall.new())
			return
			
		# If too far and team not in control, return to goal
		if entity.global_position.distance_squared_to(rear_target) > 10000 and not entity.team.controlling_player:
			entity.get_steering().target_pos = rear_target

	func exit(entity: Node) -> void:
		entity.get_steering().arrive_off()

class InterceptBall extends State:
	func enter(entity: Node) -> void:
		entity.get_steering().pursuit_on()
		
	func execute(entity: Node) -> void:
		entity.get_steering().target_agent1 = null # Ball not vehicle
		# Manual pursuit logic or Arrive
		entity.get_steering().pursuit_off()
		entity.get_steering().arrive_on()
		entity.get_steering().target_pos = entity.team.pitch.ball.global_position
		
		# Trap
		if entity.global_position.distance_squared_to(entity.team.pitch.ball.global_position) < 400: # 20^2
			entity.team.pitch.ball.trap()
			entity.team.pitch.ball.owner_player = entity
			entity.state_machine.change_state(PutBallBackInPlay.new())
			return
			
		# Too far away check?
		if entity.global_position.distance_squared_to(entity.team.home_goal.center) > 90000 and not entity.is_closest_team_member_to_ball():
			entity.state_machine.change_state(ReturnHome.new())

	func exit(entity: Node) -> void:
		entity.get_steering().all_off()

class ReturnHome extends State:
	func enter(entity: Node) -> void:
		entity.get_steering().arrive_on()
		
	func execute(entity: Node) -> void:
		var home_pos = entity.team.pitch.regions[entity.home_region].center
		entity.get_steering().target_pos = home_pos
		
		if entity.global_position.distance_squared_to(home_pos) < 100 or not entity.team.controlling_player:
			entity.state_machine.change_state(TendGoal.new())
			
	func exit(entity: Node) -> void:
		entity.get_steering().arrive_off()

class PutBallBackInPlay extends State:
	func enter(entity: Node) -> void:
		entity.velocity = Vector2.ZERO
		entity.team.controlling_player = entity
		entity.team.return_all_field_players_to_home()
		# We should also message opponent to go home? 
		# In simplified soccer, maybe just waiting a bit is enough or checking distance.
		
	func execute(entity: Node) -> void:
		# Wait for players to clear out?
		# Check if any player is too close?
		
		# Look for pass
		# Simple: Pass to any open teammate
		# Or just nearest upfield
		var receiver: PlayerBase = null
		var best_score = -1.0
		
		for p in entity.team.players:
			if p is FieldPlayer:
				if entity.team.is_pass_safe_from_all_opponents(entity.global_position, p.global_position, p):
					# Score by distance (further is better usually)
					var score = entity.global_position.distance_to(p.global_position)
					if score > best_score:
						best_score = score
						receiver = p
		
		if receiver:
			entity.team.pitch.ball.kick(receiver.global_position - entity.global_position, 300.0)
			entity.team.receiver = receiver
			MessageDispatcher.dispatch_message(0, entity, receiver, MessageTypes.MSG_RECEIVE_BALL, {"target": receiver.global_position})
			entity.state_machine.change_state(TendGoal.new())
			return
			
		# If no pass, just wait? Or kick forward blindly?
		# Kick forward if stuck
		# entity.team.pitch.ball.kick(Vector2(-entity.team.home_goal.facing_direction.x, 0), 300.0)
		# entity.state_machine.change_state(TendGoal.new())

	func exit(entity: Node) -> void:
		pass
