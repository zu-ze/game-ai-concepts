class_name Goalkeeper extends PlayerBase

func _ready() -> void:
	super._ready()
	state_machine.set_current_state(TendGoal.new())

# States ---------------------------------------------------------

class TendGoal extends State:
	func enter(entity: Node) -> void:
		entity.get_steering().flags = SteeringBehaviors.BehaviorType.ARRIVE
		
	func execute(entity: Node) -> void:
		var ball = entity.team.pitch.ball
		var goal_center = entity.team.home_goal.center
		
		# Move to point between ball and goal center
		# But constrained to goal width
		var target = (ball.global_position + goal_center) / 2.0
		
		# Clamp target to goal area (simple clamp Y)
		target.y = clamp(target.y, entity.team.home_goal.left_post.y, entity.team.home_goal.right_post.y)
		target.x = goal_center.x + (entity.team.home_goal.facing_direction.x * 20.0) # slightly in front
		
		entity.get_steering().target_pos = target
		
		# Check if ball is close enough to intercept
		if ball.global_position.distance_squared_to(entity.global_position) < 4000: # 60^2
			entity.state_machine.change_state(InterceptBall.new())

	func exit(entity: Node) -> void:
		entity.get_steering().flags = 0

class InterceptBall extends State:
	func enter(entity: Node) -> void:
		entity.get_steering().flags = SteeringBehaviors.BehaviorType.PURSUIT
		entity.get_steering().target_agent1 = null # We don't have a vehicle for ball, need to adapt steering for ball...
		# Actually Pursuit expects a Vehicle. We need Seek for ball, or create a wrapper.
		# For simplicity, use Arrive to ball.
		entity.get_steering().flags = SteeringBehaviors.BehaviorType.ARRIVE
		
	func execute(entity: Node) -> void:
		entity.get_steering().target_pos = entity.team.pitch.ball.global_position
		
		if entity.global_position.distance_squared_to(entity.team.pitch.ball.global_position) < 400: # 20^2
			entity.team.pitch.ball.trap()
			entity.team.pitch.ball.owner_player = entity
			entity.state_machine.change_state(PutBallBackInPlay.new())

	func exit(entity: Node) -> void:
		entity.get_steering().flags = 0

class PutBallBackInPlay extends State:
	func enter(entity: Node) -> void:
		entity.velocity = Vector2.ZERO
		
	func execute(entity: Node) -> void:
		# Pass to nearest teammate
		# Finding nearest teammate logic here...
		# For now, just kick forward
		var direction = Vector2(-entity.team.home_goal.facing_direction.x, 0)
		entity.team.pitch.ball.kick(direction, 300.0)
		entity.state_machine.change_state(TendGoal.new())
