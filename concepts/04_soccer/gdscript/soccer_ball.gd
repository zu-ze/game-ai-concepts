class_name SoccerBall extends RigidBody2D

# Constants
const FRICTION: float = -10.0 # Deceleration (negative value as per formula derivation logic, or magnitude)
# The text says "amount of deceleration is set in params as the value friction". 
# Usually friction is positive magnitude. The acceleration 'a' is -Friction.
# Let's define FRICTION_MAGNITUDE.
const FRICTION_MAGNITUDE: float = 150.0 # pixels/sec^2? Adjust to feel.

var old_pos: Vector2
var owner_player: Node2D = null # The player currently controlling the ball

# Pending kick to apply in next physics frame
var pending_kick_velocity: Vector2 = Vector2.ZERO
var has_pending_kick: bool = false

# Debug tracking
var last_position_log_time: float = 0.0
var position_log_interval: float = 0.5 # Log every 0.5 seconds

func _ready() -> void:
	gravity_scale = 0 # Top-down 2D soccer
	linear_damp = 0.0 # We implement custom friction
	angular_damp = 1.0
	mass = 1.0 # Explicitly set mass
	lock_rotation = true # Top-down view, no rotation needed
	freeze = false # Ensure ball is not frozen
	sleeping = false # Keep ball awake
	can_sleep = false # Prevent automatic sleeping
	
	contact_monitor = true
	max_contacts_reported = 4
	
	# Physics Layer Setup
	# Layer 1: Walls
	# Layer 2: Ball
	# Layer 3: Players
	# Ball collides with Walls (1), but not Players (3)
	collision_layer = 2
	collision_mask = 1 
	
	# Setup collision shape if not present (programmatically for demo)
	if get_child_count() == 0:
		var col = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 5.0
		col.shape = shape
		add_child(col)
		
		# Visuals
		var sprite = Sprite2D.new()
		sprite.texture = load("res://ball.png")
		sprite.scale = Vector2(0.075, 0.075)
		sprite.modulate = Color.WHITE
		add_child(sprite)
		
	old_pos = global_position

func _physics_process(delta: float) -> void:
	# Log ball position and velocity periodically for debugging
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_position_log_time >= position_log_interval:
		if linear_velocity.length() > 1.0: # Only log if moving
			var distance_moved = global_position.distance_to(old_pos)
			var expected_distance = linear_velocity.length() * position_log_interval
			print("[BALL MOVEMENT] Pos: %v, Vel: %v (%.1f px/s), Moved: %.2f px, Expected: %.2f px" % [
				global_position, linear_velocity, linear_velocity.length(), distance_moved, expected_distance
			])
			old_pos = global_position
		last_position_log_time = current_time

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Apply pending kick first (before friction)
	if has_pending_kick:
		state.linear_velocity = pending_kick_velocity
		has_pending_kick = false
		sleeping = false
		print("  [PHYSICS] Applied kick velocity: %v (%.1f)" % [pending_kick_velocity, pending_kick_velocity.length()])
	
	# Apply constant friction (deceleration)
	var vel = state.linear_velocity
	var speed = vel.length()
	
	if speed > 0:
		var drop = FRICTION_MAGNITUDE * state.step
		var new_speed = max(0, speed - drop)
		state.linear_velocity = vel.normalized() * new_speed
	
	old_pos = global_position

func kick(direction: Vector2, force: float, is_dribble: bool = false) -> void:
	direction = direction.normalized()
	
	var vel_before = linear_velocity
	
	# Calculate new velocity
	var new_velocity = direction * force
	
	# Clamp maximum velocity to prevent runaway ball
	var max_ball_speed = 600.0 # Reasonable maximum
	if new_velocity.length() > max_ball_speed:
		new_velocity = new_velocity.normalized() * max_ball_speed
	
	# Wake the ball up FIRST so _integrate_forces() will be called
	sleeping = false
	
	# Set pending kick to be applied in next physics frame
	pending_kick_velocity = new_velocity
	has_pending_kick = true
	
	print("[BALL KICK] Pos: %v, Dir: %v, Force: %.1f, Dribble: %s, Mass: %.2f" % [global_position, direction, force, is_dribble, mass])
	print("  VelBefore: %v (%.1f), VelPending: %v (%.1f), DeltaV: %.1f" % [
		vel_before, vel_before.length(), 
		new_velocity, new_velocity.length(),
		(new_velocity - vel_before).length()
	])
	
	# Clear owner when kicked
	owner_player = null

func trap() -> void:
	linear_velocity = Vector2.ZERO

func future_position(time: float) -> Vector2:
	# Formula: DeltaX = u * t + 0.5 * a * t^2
	var u = linear_velocity.length()
	var a = -FRICTION_MAGNITUDE
	
	# Check if ball stops before 'time'
	# Time to stop: 0 = u + a * t_stop => t_stop = -u / a = u / FRICTION_MAGNITUDE
	var t_stop = 0.0
	if FRICTION_MAGNITUDE > 0:
		t_stop = u / FRICTION_MAGNITUDE
	else:
		t_stop = 9999.0
		
	var t_calc = min(time, t_stop)
	
	var dist = u * t_calc + 0.5 * a * t_calc * t_calc
	
	if linear_velocity.length_squared() > 0.001:
		return global_position + linear_velocity.normalized() * dist
	else:
		return global_position

func time_to_cover_distance(from: Vector2, to: Vector2, force: float) -> float:
	# 1. Initial Velocity u = Force / Mass
	# (Assuming 'force' param is the impulse magnitude, Impulse = m * v => v = Impulse / m)
	var u = force / mass
	
	# 2. Deceleration a = -FRICTION_MAGNITUDE
	var a = -FRICTION_MAGNITUDE
	
	# 3. Distance DeltaX
	var dist = from.distance_to(to)
	
	# 4. Check if reachable: v^2 = u^2 + 2*a*dist
	# term = u^2 + 2*a*dist
	var term = u*u + 2*a*dist
	
	if term <= 0:
		return -1.0 # Cannot reach
		
	var v = sqrt(term)
	
	# 5. Time t = (v - u) / a
	# Note: v is the speed at the end. 
	# Wait, v = u + at. Since a is negative, v < u.
	# But v from sqrt is positive speed. The velocity vector direction is same.
	# Equation v = u + at handles scalars if we respect sign.
	# If u is positive speed, v is positive speed (smaller). a is negative.
	# So t = (v - u) / a should work.
	
	if abs(a) < 0.001: return dist / u # No friction case
	
	return (v - u) / a
