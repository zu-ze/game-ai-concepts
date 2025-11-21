extends CharacterBody2D

@export var speed: float = 200.0
@export var target: Node2D

func _physics_process(_delta: float) -> void:
	if target:
		# Calculate direction vector from current position to target position
		var direction = global_position.direction_to(target.global_position)
		
		# Set velocity
		velocity = direction * speed
		
		# Apply movement
		move_and_slide()
		
		# Optional: Rotate towards target
		look_at(target.global_position)
