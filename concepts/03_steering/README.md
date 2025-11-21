# Steering Behaviors

This module implements autonomous agents with steering behaviors as described in *Programming Game AI by Example*. It includes a physics-based vehicle model, a modular steering system, and spatial partitioning for efficient group behaviors.

## Components

1.  **Vehicle**: Extends `BaseGameEntity`. It has mass, velocity, max speed, and max force. It updates its position based on the calculated steering force.
2.  **SteeringBehaviors**: The core class that calculates the total steering force based on active behaviors and their weights.
3.  **CellSpacePartition**: A 2D grid system to quickly query neighbors within a radius, essential for flocking behaviors (Separation, Alignment, Cohesion) to avoid $O(N^2)$ complexity.

## Behaviors Implemented

The behaviors are bitwise flags that can be combined:

*   **Seek**: Move towards a target.
*   **Flee**: Move away from a target.
*   **Arrive**: Move towards a target and slow down as it approaches.
*   **Wander**: Move randomly but smoothly.
*   **Pursuit**: Predict a target's future position and seek it.
*   **Evade**: Predict a pursuer's future position and flee it.
*   **Separation**: Avoid crowding neighbors.
*   **Alignment**: Match heading with neighbors.
*   **Cohesion**: Move towards the center of mass of neighbors.

## Usage

### GDScript

1.  **Setup**: Attach `Vehicle.gd` to a node (or instantiate it).
2.  **Configuration**:
    ```gdscript
    var vehicle = Vehicle.new()
    add_child(vehicle)
    
    # Enable behaviors using bitwise OR
    var steering = vehicle.get_steering()
    steering.flags = SteeringBehaviors.BehaviorType.SEEK | SteeringBehaviors.BehaviorType.WANDER
    
    # Set targets
    steering.target_pos = Vector2(100, 100)
    ```

### C#

1.  **Setup**: Ensure the solution is built. Instantiate `Vehicle` class.
2.  **Configuration**:
    ```csharp
    var vehicle = new Vehicle();
    AddChild(vehicle);
    
    // Enable behaviors
    vehicle.Steering.Flags = SteeringBehaviors.BehaviorType.Seek | SteeringBehaviors.BehaviorType.Wander;
    
    // Set targets
    vehicle.Steering.TargetPos = new Vector2(100, 100);
    ```

## Spatial Partitioning

To use flocking efficiently with many agents:

1.  Initialize `CellSpacePartition` with the world size and grid dimensions.
2.  Register entities: `cell_space.add_entity(vehicle)`
3.  Each frame:
    *   Clear/Update partition.
    *   For each vehicle, query neighbors: `neighbors = cell_space.calculate_neighbors(pos, radius)`
    *   Pass neighbors to the steering behavior: `vehicle.steering.neighbors = neighbors`

## Demo

Run `concepts/03_steering/steering_demo.tscn` to see a flocking simulation.
- The demo spawns 50 agents.
- They wrap around the screen.
- They use Wander, Separation, Alignment, and Cohesion.
