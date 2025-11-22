class_name SoccerBall extends RigidBody2D

# Using RigidBody2D for the ball simplifies physics collision and response.
# However, standard game AI texts often implement their own physics for total control.
# Here we combine Godot's physics with AI methods.

var old_pos: Vector2
var owner_player: Node2D = null # The player currently controlling the ball

func _ready() -> void:
	gravity_scale = 0 # Top-down 2D soccer
	linear_damp = 1.0 # Rolling friction
	contact_monitor = true
	max_contacts_reported = 4
	
	# Setup collision shape if not present (programmatically for demo)
	if get_child_count() == 0:
		var col = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 5.0
		col.shape = shape
		add_child(col)
		
		# Visuals
		var sprite = Sprite2D.new()
		sprite.texture = load("res://icon.svg")
		sprite.scale = Vector2(0.1, 0.1)
		sprite.modulate = Color.WHITE
		add_child(sprite)

func kick(direction: Vector2, force: float) -> void:
	direction = direction.normalized()
	apply_central_impulse(direction * force)
	# Clear owner when kicked
	owner_player = null

func trap() -> void:
	linear_velocity = Vector2.ZERO

func future_position(time: float) -> Vector2:
	# Simple prediction assuming constant velocity (ignoring drag for prediction simplicity)
	return global_position + linear_velocity * time

func time_to_cover_distance(from: Vector2, to: Vector2, force: float) -> float:
	# This is a simplification. 
	# Distance = Speed * Time -> Time = Dist / Speed
	# But friction applies.
	# Using a heuristic for now.
	var speed = force # Impulse approximates initial speed roughly in unit mass
	if speed <= 0: return 1000.0
	return from.distance_to(to) / speed
