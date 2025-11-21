extends Node2D

@export var vehicle_count: int = 50
@export var use_csharp: bool = false

# Spatial partitioning
var cell_space: CellSpacePartition
var width: float
var height: float

var _vehicles: Array[Vehicle] = []

func _ready() -> void:
	var viewport_rect = get_viewport_rect()
	width = viewport_rect.size.x
	height = viewport_rect.size.y
	
	# Initialize Spatial Partition
	# 10x10 grid
	cell_space = CellSpacePartition.new(width, height, 10, 10)
	
	# Spawn vehicles
	for i in range(vehicle_count):
		_spawn_vehicle()

func _spawn_vehicle() -> void:
	var v: Vehicle
	if use_csharp:
		var script = load("res://concepts/03_steering/csharp/Vehicle.cs")
		if script:
			v = script.new()
	else:
		v = Vehicle.new()
	
	if v:
		v.position = Vector2(randf() * width, randf() * height)
		v.rotation = randf() * TAU
		
		# Setup Flocking behaviors
		var sb = v.get_steering()
		# Turn on wander + separation + cohesion + alignment
		# In GDScript flags are just integers, we need to combine them.
		# Accessing the enum from the instance or script class
		# Using hardcoded ints for brevity if constants aren't easily reachable across language barrier
		# But here we are in GDScript controlling GDScript mainly.
		
		# WANDER(8) | SEPARATION(32) | ALIGNMENT(64) | COHESION(16) = 120
		# Or better use the constants if available
		var behaviors = 0
		behaviors |= SteeringBehaviors.BehaviorType.WANDER
		behaviors |= SteeringBehaviors.BehaviorType.SEPARATION
		behaviors |= SteeringBehaviors.BehaviorType.ALIGNMENT
		behaviors |= SteeringBehaviors.BehaviorType.COHESION
		
		sb.flags = behaviors
		
		# Add visual representation
		var sprite = Sprite2D.new()
		sprite.texture = load("res://icon.svg")
		sprite.scale = Vector2(0.2, 0.2)
		v.add_child(sprite)
		
		# Wrap around screen
		# (Implementation of wrap around needs to be in _process or physics process of vehicle or manager)
		# For this demo, we will add a wrap component or just logic here
		
		add_child(v)
		_vehicles.append(v)
		cell_space.add_entity(v)

func _physics_process(_delta: float) -> void:
	# Update spatial partition
	# Ideally this is efficient, but here we just clear and re-add or update
	# Simpler: Re-add all.
	cell_space.empty_cells()
	for v in _vehicles:
		_wrap_around(v)
		cell_space.add_entity(v)
		
	# Update neighbors for each vehicle
	for v in _vehicles:
		var sb = v.get_steering()
		sb.neighbors = cell_space.calculate_neighbors(v.global_position, 100.0) # View distance

func _wrap_around(v: Node2D) -> void:
	if v.position.x < 0: v.position.x = width
	if v.position.x > width: v.position.x = 0
	if v.position.y < 0: v.position.y = height
	if v.position.y > height: v.position.y = 0
