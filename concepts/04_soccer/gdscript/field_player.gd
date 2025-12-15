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
	func _init() -> void:
		state_name = "FieldPlayerGlobal"
	
	func execute(entity: Node) -> void:
		# Slow down if controlling ball
		if entity.is_controlling_ball():
			entity.max_speed = 300.0
		else:
			entity.max_speed = 450.0
		
	func on_message(entity: Node, telegram: Telegram) -> bool:
		if telegram.msg == MessageTypes.MSG_GO_HOME:
			entity.get_steering().target_pos = entity.team.pitch.regions[entity.home_region].center
			entity.state_machine.change_state(ReturnToHome.new())
			return true
		elif telegram.msg == MessageTypes.MSG_RECEIVE_BALL:
			# Extra info contains target position
			var target = telegram.extra_info.get("target", entity.global_position)
			entity.get_steering().target_pos = target
			entity.state_machine.change_state(ReceiveBall.new())
			return true
		elif telegram.msg == MessageTypes.MSG_SUPPORT_ATTACKER:
			if not entity.is_controlling_ball():
				entity.state_machine.change_state(SupportAttacker.new())
				return true
		elif telegram.msg == MessageTypes.MSG_WAIT:
			entity.state_machine.change_state(Wait.new())
			return true
		elif telegram.msg == MessageTypes.MSG_PASS_TO_ME:
			# Request from teammate
			var receiver = telegram.sender as FieldPlayer
			if entity.is_controlling_ball() and receiver:
				# Pass ball
				# Calculate force?
				var kick_target = receiver.global_position
				entity.team.pitch.ball.kick(kick_target - entity.global_position, 250.0)
				entity.team.receiver = receiver
				# Tell receiver to receive
				MessageDispatcher.dispatch_message(0, entity, receiver, MessageTypes.MSG_RECEIVE_BALL, {"target": kick_target})
				entity.state_machine.change_state(Wait.new())
			return true
			
		return false

class Wait extends State:
	func _init() -> void:
		state_name = "Wait"
	
	func enter(entity: Node) -> void:
		print("[%s P%d] ENTER Wait" % [entity.team.name, entity.team.players.find(entity)])
		entity.velocity = Vector2.ZERO
		entity.get_steering().all_off()
		
	func execute(entity: Node) -> void:
		if entity.is_closest_team_member_to_ball() and \
		   entity.team.receiver != entity and \
		   not entity.team.pitch.ball.owner_player:
			print("[%s P%d] Wait -> ChaseBall (closest to ball)" % [entity.team.name, entity.team.players.find(entity)])
			entity.state_machine.change_state(ChaseBall.new())
			return
		
		# If upfield of controller, request pass
		if entity.team.controlling_player and not entity.is_controlling_ball():
			# Simple check for "upfield" relative to goal
			var dist_to_goal = entity.global_position.distance_squared_to(entity.team.opponents_goal.center)
			var controller_dist = entity.team.controlling_player.global_position.distance_squared_to(entity.team.opponents_goal.center)
			if dist_to_goal < controller_dist:
				entity.team.request_pass(entity)
	
	func exit(entity: Node) -> void:
		pass

class ReceiveBall extends State:
	func _init() -> void:
		state_name = "ReceiveBall"
	
	func enter(entity: Node) -> void:
		entity.get_steering().arrive_on()
		# Target set by message
		
	func execute(entity: Node) -> void:
		if entity.is_closest_team_member_to_ball() and \
		   entity.global_position.distance_squared_to(entity.team.pitch.ball.global_position) < 400:
			entity.state_machine.change_state(ChaseBall.new())
			return
			
		if not entity.team.controlling_player and not entity.team.receiver == entity:
			entity.state_machine.change_state(ChaseBall.new())

	func exit(entity: Node) -> void:
		entity.get_steering().arrive_off()
		entity.team.receiver = null

class ChaseBall extends State:
	func _init() -> void:
		state_name = "ChaseBall"
	
	func enter(entity: Node) -> void:
		print("[%s P%d] ENTER ChaseBall - Ball at: %v" % [entity.team.name, entity.team.players.find(entity), entity.team.pitch.ball.global_position])
		entity.get_steering().seek_on()
		print("[%s P%d] Steering: Seek ON, max_speed=%.1f, max_force=%.1f" % [entity.team.name, entity.team.players.find(entity), entity.max_speed, entity.max_force])
		
	func execute(entity: Node) -> void:
		var ball_pos = entity.team.pitch.ball.global_position
		entity.get_steering().target_pos = ball_pos
		var dist_to_ball = entity.global_position.distance_to(ball_pos)
		
		if entity.is_controlling_ball():
			print("[%s P%d] ChaseBall -> KickBall (controlling ball, dist: %.1f)" % [entity.team.name, entity.team.players.find(entity), dist_to_ball])
			entity.state_machine.change_state(KickBall.new())
			return
			
		if not entity.is_closest_team_member_to_ball():
			print("[%s P%d] ChaseBall -> ReturnToHome (no longer closest)" % [entity.team.name, entity.team.players.find(entity)])
			entity.state_machine.change_state(ReturnToHome.new())

	func exit(entity: Node) -> void:
		entity.get_steering().seek_off()

class Dribble extends State:
	func _init() -> void:
		state_name = "Dribble"
	
	func enter(entity: Node) -> void:
		print("[%s P%d] ENTER Dribble" % [entity.team.name, entity.team.players.find(entity)])
		entity.team.controlling_player = entity
		entity.get_steering().all_off()
		
	func execute(entity: Node) -> void:
		# Cooldown check - prevent rapid dribble loops
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - entity.last_dribble_time < 0.5: # 0.5 second cooldown
			print("[%s P%d] DRIBBLE on cooldown (%.2fs ago), waiting..." % [
				entity.team.name, 
				entity.team.players.find(entity),
				current_time - entity.last_dribble_time
			])
			return
		
		var ball = entity.team.pitch.ball
		var goal_dir = (entity.team.opponents_goal.center - entity.global_position).normalized()
		var dot = entity.heading.dot(goal_dir)
		
		# Use moderate force - between too weak (5) and too strong (150)
		var dribble_force = 50.0
		
		if dot < 0.9: # Not facing goal well
			# Swivel kick (kick sideways/angled)
			# Simplified: Kick small angle towards goal
			var kick_dir = goal_dir
			print("[%s P%d] DRIBBLE swivel kick towards goal (dot: %.2f, force: %.1f)" % [entity.team.name, entity.team.players.find(entity), dot, dribble_force])
			ball.kick(kick_dir, dribble_force, true)  # true = is_dribble
		else:
			# Kick forward
			print("[%s P%d] DRIBBLE forward kick (dot: %.2f, force: %.1f)" % [entity.team.name, entity.team.players.find(entity), dot, dribble_force])
			ball.kick(entity.heading, dribble_force, true)  # true = is_dribble
		
		entity.last_dribble_time = current_time
		entity.state_machine.change_state(ChaseBall.new())
		
	func exit(entity: Node) -> void:
		pass

class KickBall extends State:
	func _init() -> void:
		state_name = "KickBall"
	
	func enter(entity: Node) -> void:
		print("[%s P%d] ENTER KickBall" % [entity.team.name, entity.team.players.find(entity)])
		entity.velocity = Vector2.ZERO
		entity.get_steering().all_off()
		entity.team.controlling_player = entity
		
	func execute(entity: Node) -> void:
		var ball = entity.team.pitch.ball
		var to_ball = ball.global_position - entity.global_position
		var dot = entity.heading.dot(to_ball.normalized())
		
		# Can kick check
		if dot < 0: # Ball behind
			print("[%s P%d] KickBall -> ChaseBall (ball behind)" % [entity.team.name, entity.team.players.find(entity)])
			entity.state_machine.change_state(ChaseBall.new())
			return
			
		# 1. Shot
		var shot_power = 300.0
		var shot_info = entity.team.can_shoot(entity.global_position, shot_power)
		if shot_info.can_shoot:
			print("[%s P%d] SHOOTING at goal! Target: %v" % [entity.team.name, entity.team.players.find(entity), shot_info.target])
			ball.kick(shot_info.target - entity.global_position, shot_power)
			entity.state_machine.change_state(Wait.new())
			return
			
		# 2. Pass
		# Use FindPass instead of just checking supporting player
		var pass_info = entity.team.find_pass(entity, 250.0)
		if pass_info.success:
			var receiver = pass_info.receiver
			var target = pass_info.target
			
			print("[%s P%d] PASSING to P%d at %v" % [entity.team.name, entity.team.players.find(entity), entity.team.players.find(receiver), target])
			ball.kick(target - entity.global_position, 250.0)
			entity.team.receiver = receiver
			MessageDispatcher.dispatch_message(0, entity, receiver, MessageTypes.MSG_RECEIVE_BALL, {"target": target})
			entity.state_machine.change_state(Wait.new())
			return
			
		# 3. Dribble
		print("[%s P%d] KickBall -> Dribble (no shot/pass available)" % [entity.team.name, entity.team.players.find(entity)])
		entity.state_machine.change_state(Dribble.new())

	func exit(entity: Node) -> void:
		pass

class SupportAttacker extends State:
	func _init() -> void:
		state_name = "SupportAttacker"
	
	func enter(entity: Node) -> void:
		entity.get_steering().arrive_on()
		entity.get_steering().target_pos = entity.team.get_support_spot()
		
	func execute(entity: Node) -> void:
		# If team loses control
		if not entity.team.controlling_player:
			entity.state_machine.change_state(ReturnToHome.new())
			return
			
		# Update target
		var bss = entity.team.get_support_spot()
		if bss != entity.get_steering().target_pos:
			entity.get_steering().target_pos = bss
			
		# Request pass if at target and safe
		if entity.global_position.distance_squared_to(bss) < 100:
			entity.velocity = Vector2.ZERO
			entity.get_steering().all_off()
			
			# can_shoot returns dict now, checking 'can_shoot' key
			if not entity.is_threatened() and entity.team.can_shoot(entity.global_position, 300.0).can_shoot:
				entity.team.request_pass(entity)

	func exit(entity: Node) -> void:
		entity.get_steering().all_off()

class ReturnToHome extends State:
	func _init() -> void:
		state_name = "ReturnToHome"
	
	func enter(entity: Node) -> void:
		var region = entity.team.pitch.regions[entity.home_region]
		print("[%s P%d] ENTER ReturnToHome - Target: %v" % [entity.team.name, entity.team.players.find(entity), region.center])
		entity.get_steering().arrive_on()
		
	func execute(entity: Node) -> void:
		var region = entity.team.pitch.regions[entity.home_region]
		entity.get_steering().target_pos = region.center
		
		if entity.is_closest_team_member_to_ball() and not entity.team.pitch.ball.owner_player:
			print("[%s P%d] ReturnToHome -> ChaseBall (now closest)" % [entity.team.name, entity.team.players.find(entity)])
			entity.state_machine.change_state(ChaseBall.new())
			return
			
		var dist_to_home = entity.global_position.distance_to(region.center)
		if entity.global_position.distance_squared_to(region.center) < 100:
			print("[%s P%d] ReturnToHome -> Wait (reached home, dist: %.1f)" % [entity.team.name, entity.team.players.find(entity), dist_to_home])
			entity.state_machine.change_state(Wait.new())

	func exit(entity: Node) -> void:
		entity.get_steering().arrive_off()
