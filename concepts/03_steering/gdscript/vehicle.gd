class_name Vehicle extends BaseGameEntity

@export var max_speed: float = 150.0
@export var max_force: float = 100.0
@export var mass: float = 1.0
@export var max_turn_rate: float = 5.0 # Radians per second

var steering: SteeringBehaviors
var heading: Vector2 = Vector2.RIGHT
var side: Vector2 = Vector2.DOWN

# For smoothing
var _smoothed_heading: Vector2 = Vector2.RIGHT
const NUM_SAMPLES_FOR_SMOOTHING = 5
var _heading_samples: Array[Vector2] = []

func _ready() -> void:
	super._ready()
	steering = SteeringBehaviors.new(self)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	var steering_force = steering.calculate(delta)
	
	# Acceleration = Force / Mass
	var acceleration = steering_force / mass
	
	# Update velocity
	velocity += acceleration * delta
	
	# Truncate speed
	velocity = velocity.limit_length(max_speed)
	
	# Update heading if velocity is significant
	if velocity.length_squared() > 0.0001:
		heading = velocity.normalized()
		side = heading.orthogonal()
		rotation = heading.angle()
	
	move_and_slide()
	
	# Enforce non-overlap (simple circle based) if using spatial partitioning
	# (To be implemented in spatial partitioning step or manager)

func get_steering() -> SteeringBehaviors:
	return steering
