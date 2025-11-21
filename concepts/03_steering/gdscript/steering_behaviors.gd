class_name SteeringBehaviors extends RefCounted

enum SummingMethod { WEIGHTED_AVERAGE, PRIORITIZED, DITHERED }
enum BehaviorType {
	NONE = 0,
	SEEK = 1 << 0,
	FLEE = 1 << 1,
	ARRIVE = 1 << 2,
	WANDER = 1 << 3,
	COHESION = 1 << 4,
	SEPARATION = 1 << 5,
	ALIGNMENT = 1 << 6,
	OBSTACLE_AVOIDANCE = 1 << 7,
	WALL_AVOIDANCE = 1 << 8,
	FOLLOW_PATH = 1 << 9,
	PURSUIT = 1 << 10,
	EVADE = 1 << 11,
	INTERPOSE = 1 << 12,
	HIDE = 1 << 13,
	OFFSET_PURSUIT = 1 << 14,
}

var vehicle: Vehicle
var flags: int = 0

# Targets
var target_agent1: Vehicle
var target_agent2: Vehicle
var target_pos: Vector2
var path: SteeringPath

# Weights
var weight_seek: float = 1.0
var weight_flee: float = 1.0
var weight_arrive: float = 1.0
var weight_wander: float = 1.0
var weight_cohesion: float = 2.0
var weight_separation: float = 5.0
var weight_alignment: float = 1.0
var weight_obstacle_avoidance: float = 10.0
var weight_wall_avoidance: float = 10.0
var weight_pursuit: float = 1.0
var weight_evade: float = 1.0
var weight_follow_path: float = 1.0
var weight_hide: float = 1.0
var weight_interpose: float = 1.0
var weight_offset_pursuit: float = 1.0

# Wander internal state
var wander_radius: float = 30.0
var wander_distance: float = 50.0
var wander_jitter: float = 40.0 # per second
var wander_target: Vector2 = Vector2.ZERO

# Avoidance
var detection_length: float = 100.0
# Neighbors for flocking
var neighbors: Array[Vehicle] = []
# For obstacle avoidance
var obstacles: Array[BaseGameEntity] = []
# For wall avoidance
var walls: Array[Wall] = []
# For path following
var waypoint_seek_dist_sq: float = 20.0 * 20.0
# For offset pursuit
var offset: Vector2 = Vector2.ZERO

func _init(p_vehicle: Vehicle) -> void:
	vehicle = p_vehicle
	# Initialize wander target on the circle perimeter
	var theta = randf() * TAU
	wander_target = Vector2(cos(theta), sin(theta)) * wander_radius

func calculate(_delta: float) -> Vector2:
	var steering_force = Vector2.ZERO
	steering_force = _calculate_weighted_sum()
	return steering_force

func _calculate_weighted_sum() -> Vector2:
	var force = Vector2.ZERO
	
	if _on(BehaviorType.OBSTACLE_AVOIDANCE):
		force += _obstacle_avoidance(obstacles) * weight_obstacle_avoidance

	if _on(BehaviorType.WALL_AVOIDANCE):
		force += _wall_avoidance(walls) * weight_wall_avoidance

	if _on(BehaviorType.SEEK):
		force += _seek(target_pos) * weight_seek
		
	if _on(BehaviorType.FLEE):
		force += _flee(target_pos) * weight_flee
		
	if _on(BehaviorType.ARRIVE):
		force += _arrive(target_pos, 2) * weight_arrive # Deceleration.normal
		
	if _on(BehaviorType.WANDER):
		force += _wander() * weight_wander

	if _on(BehaviorType.PURSUIT) and target_agent1:
		force += _pursuit(target_agent1) * weight_pursuit
		
	if _on(BehaviorType.EVADE) and target_agent1:
		force += _evade(target_agent1) * weight_evade
		
	if _on(BehaviorType.INTERPOSE) and target_agent1 and target_agent2:
		force += _interpose(target_agent1, target_agent2) * weight_interpose
		
	if _on(BehaviorType.HIDE) and target_agent1:
		force += _hide(target_agent1, obstacles) * weight_hide

	if _on(BehaviorType.FOLLOW_PATH) and path:
		force += _follow_path() * weight_follow_path
		
	if _on(BehaviorType.OFFSET_PURSUIT) and target_agent1:
		force += _offset_pursuit(target_agent1, offset) * weight_offset_pursuit

	if _on(BehaviorType.SEPARATION):
		force += _separation(neighbors) * weight_separation
		
	if _on(BehaviorType.ALIGNMENT):
		force += _alignment(neighbors) * weight_alignment
		
	if _on(BehaviorType.COHESION):
		force += _cohesion(neighbors) * weight_cohesion

	return force.limit_length(vehicle.max_force)

func _on(bt: BehaviorType) -> bool:
	return (flags & bt) == bt

# Behaviors ----------------------------------------------------------

func _seek(target: Vector2) -> Vector2:
	var desired_velocity = (target - vehicle.global_position).normalized() * vehicle.max_speed
	return desired_velocity - vehicle.velocity

func _flee(target: Vector2) -> Vector2:
	var panic_distance_sq = 100.0 * 100.0
	if vehicle.global_position.distance_squared_to(target) > panic_distance_sq:
		return Vector2.ZERO
		
	var desired_velocity = (vehicle.global_position - target).normalized() * vehicle.max_speed
	return desired_velocity - vehicle.velocity

func _arrive(target: Vector2, deceleration: int) -> Vector2:
	var to_target = target - vehicle.global_position
	var dist = to_target.length()
	
	if dist > 0:
		# Deceleration tweak
		var speed = dist / (float(deceleration) * 0.3)
		speed = min(speed, vehicle.max_speed)
		
		var desired_velocity = to_target * (speed / dist)
		return desired_velocity - vehicle.velocity
	
	return Vector2.ZERO

func _wander() -> Vector2:
	# Add small random vector to target
	var jitter = wander_jitter * 0.016 # assumes 60fps or pass delta
	wander_target += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * jitter
	wander_target = wander_target.normalized() * wander_radius
	
	var target_local = wander_target + Vector2(wander_distance, 0)
	# Transform to world space (simplified 2D rotation)
	var target_world = vehicle.global_position + target_local.rotated(vehicle.rotation)
	
	return target_world - vehicle.global_position

func _pursuit(evader: Vehicle) -> Vector2:
	var to_evader = evader.global_position - vehicle.global_position
	var relative_heading = vehicle.heading.dot(evader.heading)
	
	if to_evader.dot(vehicle.heading) > 0 and relative_heading < -0.95:
		return _seek(evader.global_position)
		
	var look_ahead_time = to_evader.length() / (vehicle.max_speed + evader.velocity.length())
	return _seek(evader.global_position + evader.velocity * look_ahead_time)

func _evade(pursuer: Vehicle) -> Vector2:
	var to_pursuer = pursuer.global_position - vehicle.global_position
	var look_ahead_time = to_pursuer.length() / (vehicle.max_speed + pursuer.velocity.length())
	return _flee(pursuer.global_position + pursuer.velocity * look_ahead_time)

func _obstacle_avoidance(obstacles_list: Array[BaseGameEntity]) -> Vector2:
	var box_length = detection_length + (vehicle.velocity.length() / vehicle.max_speed) * detection_length
	
	var closest_intersecting_obstacle: BaseGameEntity = null
	var dist_to_closest_ip = INF
	var local_pos_of_closest_obstacle = Vector2.ZERO
	
	# Transform: We need to convert obstacles to vehicle's local space.
	# Simplified 2D transformation:
	# Local X is vehicle Heading, Local Y is vehicle Side.
	# For Godot 2D, we can use Transform2D relative to vehicle.
	var vehicle_transform = vehicle.global_transform
	var inverse_transform = vehicle_transform.affine_inverse()
	
	for obs in obstacles_list:
		var local_pos = inverse_transform * obs.global_position
		
		# Filter out obstacles behind or too far
		if local_pos.x >= 0 and local_pos.x < box_length + obs.bounding_radius:
			# Filter out obstacles not intersecting the detection box width
			# expanded by obstacle radius
			var expanded_radius = obs.bounding_radius + vehicle.bounding_radius
			
			if abs(local_pos.y) < expanded_radius:
				# Line-Circle intersection test (simplified for x-axis ray)
				# Center of circle is (local_pos.x, local_pos.y)
				# We want smallest X intersection
				var c_x = local_pos.x
				var c_y = local_pos.y
				
				# dist to intersection point along x axis
				# sqrt(radius^2 - y^2)
				var sqrt_part = sqrt(expanded_radius*expanded_radius - c_y*c_y)
				var ip = c_x - sqrt_part
				
				if ip <= 0:
					ip = c_x + sqrt_part
					
				if ip < dist_to_closest_ip:
					dist_to_closest_ip = ip
					closest_intersecting_obstacle = obs
					local_pos_of_closest_obstacle = local_pos
					
	var steering_force = Vector2.ZERO
	
	if closest_intersecting_obstacle:
		# Lateral force
		var multiplier = 1.0 + (box_length - local_pos_of_closest_obstacle.x) / box_length
		steering_force.y = (closest_intersecting_obstacle.bounding_radius - local_pos_of_closest_obstacle.y) * multiplier
		
		# Braking force
		var braking_weight = 0.2
		steering_force.x = (closest_intersecting_obstacle.bounding_radius - local_pos_of_closest_obstacle.x) * braking_weight
		
		# Convert local force to world space
		# Force X acts along Heading, Force Y acts along Side
		# But wait, steering_force here is in local space where X is forward, Y is side (down in Godot 2D?)
		# Actually in our transformation: X is forward (heading), Y is side orthogonal
		# We need to rotate this vector back by vehicle rotation
		return steering_force.rotated(vehicle.rotation)
		
	return steering_force

func _wall_avoidance(walls_list: Array[Wall]) -> Vector2:
	var feelers = _create_feelers()
	var steering_force = Vector2.ZERO
	var dist_to_closest_ip = INF
	var closest_wall: Wall = null
	var closest_point = Vector2.ZERO
	
	# For each feeler, check intersection with walls
	for feeler in feelers:
		for wall in walls_list:
			var intersection = Geometry2D.segment_intersects_segment(vehicle.global_position, feeler, wall.from, wall.to)
			if intersection:
				var dist = vehicle.global_position.distance_to(intersection)
				if dist < dist_to_closest_ip:
					dist_to_closest_ip = dist
					closest_wall = wall
					closest_point = intersection
		
		if closest_wall:
			var overshoot = feeler - closest_point
			steering_force = closest_wall.normal * overshoot.length()
			
	return steering_force

func _create_feelers() -> Array[Vector2]:
	var feelers: Array[Vector2] = []
	var feeler_length = detection_length
	
	# Front feeler
	feelers.append(vehicle.global_position + vehicle.heading * feeler_length)
	
	# Side feelers (rotated 45 degrees left and right)
	var left = vehicle.heading.rotated(deg_to_rad(-45.0)) * (feeler_length * 0.5)
	var right = vehicle.heading.rotated(deg_to_rad(45.0)) * (feeler_length * 0.5)
	
	feelers.append(vehicle.global_position + left)
	feelers.append(vehicle.global_position + right)
	
	return feelers

func _interpose(agent_a: Vehicle, agent_b: Vehicle) -> Vector2:
	var mid_point = (agent_a.global_position + agent_b.global_position) / 2.0
	var time_to_mid = vehicle.global_position.distance_to(mid_point) / vehicle.max_speed
	
	var a_future = agent_a.global_position + agent_a.velocity * time_to_mid
	var b_future = agent_b.global_position + agent_b.velocity * time_to_mid
	
	mid_point = (a_future + b_future) / 2.0
	
	return _arrive(mid_point, 0) # Fast deceleration

func _hide(hunter: Vehicle, obstacles_list: Array[BaseGameEntity]) -> Vector2:
	var dist_to_closest = INF
	var best_hiding_spot = Vector2.ZERO
	var found_spot = false
	
	for obs in obstacles_list:
		var hiding_spot = _get_hiding_position(obs.global_position, obs.bounding_radius, hunter.global_position)
		var dist = hiding_spot.distance_squared_to(vehicle.global_position)
		
		if dist < dist_to_closest:
			dist_to_closest = dist
			best_hiding_spot = hiding_spot
			found_spot = true
			
	if found_spot:
		return _arrive(best_hiding_spot, 0)
	
	return _evade(hunter)

func _get_hiding_position(obs_pos: Vector2, radius: float, hunter_pos: Vector2) -> Vector2:
	var dist_from_boundary = 30.0
	var dist_away = radius + dist_from_boundary
	var to_obs = (obs_pos - hunter_pos).normalized()
	return obs_pos + to_obs * dist_away

func _follow_path() -> Vector2:
	if path.is_finished():
		return _arrive(path.get_current_waypoint(), 2)
	
	var target = path.get_current_waypoint()
	if vehicle.global_position.distance_squared_to(target) < waypoint_seek_dist_sq:
		path.set_next_waypoint()
		
	if not path.is_finished():
		return _seek(path.get_current_waypoint())
	else:
		return _arrive(path.get_current_waypoint(), 2)

func _offset_pursuit(leader: Vehicle, offset: Vector2) -> Vector2:
	# offset is in leader's local space. Transform to world.
	# Assuming leader has typical rotation.
	var world_offset = offset.rotated(leader.rotation)
	var world_target = leader.global_position + world_offset
	
	var to_offset = world_target - vehicle.global_position
	var look_ahead_time = to_offset.length() / (vehicle.max_speed + leader.velocity.length())
	
	return _arrive(world_target + leader.velocity * look_ahead_time, 0)

# Group Behaviors ----------------------------------------------------

func _separation(neighbors_list: Array[Vehicle]) -> Vector2:
	var force = Vector2.ZERO
	for neighbor in neighbors_list:
		if neighbor != vehicle:
			var to_agent = vehicle.global_position - neighbor.global_position
			var dist = to_agent.length()
			if dist < 50.0: # separation radius
				force += to_agent.normalized() / dist
	return force

func _alignment(neighbors_list: Array[Vehicle]) -> Vector2:
	var avg_heading = Vector2.ZERO
	var count = 0
	for neighbor in neighbors_list:
		if neighbor != vehicle and vehicle.global_position.distance_squared_to(neighbor.global_position) < 10000: # 100^2
			avg_heading += neighbor.heading
			count += 1
			
	if count > 0:
		avg_heading /= count
		avg_heading -= vehicle.heading
	
	return avg_heading

func _cohesion(neighbors_list: Array[Vehicle]) -> Vector2:
	var center_mass = Vector2.ZERO
	var count = 0
	for neighbor in neighbors_list:
		if neighbor != vehicle and vehicle.global_position.distance_squared_to(neighbor.global_position) < 10000:
			center_mass += neighbor.global_position
			count += 1
			
	if count > 0:
		center_mass /= count
		return _seek(center_mass)
	
	return Vector2.ZERO
