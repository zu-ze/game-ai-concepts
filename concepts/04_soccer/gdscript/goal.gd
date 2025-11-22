class_name Goal extends Node2D

var left_post: Vector2
var right_post: Vector2
var facing_direction: Vector2
var center: Vector2
var scored_count: int = 0

func _init(p_left: Vector2, p_right: Vector2, p_facing: Vector2) -> void:
	left_post = p_left
	right_post = p_right
	facing_direction = p_facing
	center = (left_post + right_post) / 2.0

func check_score(ball: RigidBody2D) -> bool:
	# Simple AABB or Line check.
	# Assuming horizontal goals for this demo (Left and Right of screen)
	# If facing right, goal is on left.
	
	if facing_direction.x > 0: # Left Goal
		if ball.global_position.x < center.x and ball.global_position.y > left_post.y and ball.global_position.y < right_post.y:
			return true
	else: # Right Goal
		if ball.global_position.x > center.x and ball.global_position.y > left_post.y and ball.global_position.y < right_post.y:
			return true
			
	return false
