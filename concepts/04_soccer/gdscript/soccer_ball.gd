class_name SoccerBall extends RigidBody2D

# Constants
const FRICTION: float = -10.0 # Deceleration (negative value as per formula derivation logic, or magnitude)
# The text says "amount of deceleration is set in params as the value friction". 
# Usually friction is positive magnitude. The acceleration 'a' is -Friction.
# Let's define FRICTION_MAGNITUDE.
const FRICTION_MAGNITUDE: float = 150.0 # pixels/sec^2? Adjust to feel.

var old_pos: Vector2
var owner_player: Node2D = null # The player currently controlling the ball

func _ready() -> void:
	gravity_scale = 0 # Top-down 2D soccer
	linear_damp = 0.0 # We implement custom friction
	angular_damp = 1.0
	
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

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Apply constant friction (deceleration)
	var vel = state.linear_velocity
	var speed = vel.length()
	
	if speed > 0:
		var drop = FRICTION_MAGNITUDE * state.step
		var new_speed = max(0, speed - drop)
		state.linear_velocity = vel.normalized() * new_speed
	
	old_pos = global_position

func kick(direction: Vector2, force: float) -> void:
	direction = direction.normalized()
	# Force in this context is treated as an impulse that sets instantaneous velocity
	# The book says u = a_kick. But typically Impuse = F * dt = m * dv. 
	# If 'force' param here means the resulting speed (as used in previous code), we apply impulse mass * force.
	# However, text says "acceleration a = F/m" where u is treated as initial acceleration? 
	# "u is treated as the initial instantaneous acceleration applied by the force of the kick" -> u = F/m?
	# That implies u is Velocity. So F must be Impulse.
	# Let's assume the 'force' parameter passed in is the desired Force magnitude, and we calculate impulse or just set velocity?
	# Simpler: apply_central_impulse(direction * force). 
	# If force is "The kicking force", then Impulse = Force * dt? No, Kick is instantaneous.
	# Let's treat 'force' param as "Impulse Magnitude".
	
	apply_central_impulse(direction * force)
	
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
