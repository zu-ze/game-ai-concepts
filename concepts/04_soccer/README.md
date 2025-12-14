# Soccer Simulation AI

This project implements a comprehensive AI simulation for a soccer game, featuring state-driven agents, team tactics, steering behaviors, and physics-based ball movement.

## 🏗️ Architecture

The system is built using a **Tiered AI** approach:
1.  **Team AI (`SoccerTeam`)**: High-level strategy (Attacking vs Defending) and tactical analysis (Best Supporting Spot, Pass Safety).
2.  **Player AI (`FieldPlayer`, `Goalkeeper`)**: Individual decision-making using Finite State Machines (FSM).
3.  **Steering Behaviors**: Low-level movement logic (Seek, Arrive, Interpose).

### Core Classes

#### `SoccerPitch`
-   **Role**: The game environment manager.
-   **Responsibilities**:
	-   Owns the `SoccerBall`, `SoccerTeam`s (Red and Blue), `Goal`s, and `Region`s.
	-   Manages walls and goal detection.
	-   Visualizes the pitch, goals, and tactical regions.

#### `SoccerBall`
-   **Role**: A physics-based entity representing the ball.
-   **Physics**: Implements custom friction (constant deceleration) derived from kinematic equations.
-   **Prediction**: Provides `FuturePosition(time)` and `TimeToCoverDistance(A, B, force)` for AI planning.

#### `SoccerTeam`
-   **Role**: Manages a group of players and high-level strategy.
-   **FSM States**:
	-   `PrepareForKickOff`: Resets positions after a goal.
	-   `TeamDefending`: Players retract to defensive home regions.
	-   `TeamAttacking`: Players push forward to offensive home regions.
-   **Tactical Methods**:
	-   `DetermineBestSupportingSpot()`: Calculates optimal position for a supporting player.
	-   `IsPassSafeFromAllOpponents()`: Physics-based check if an opponent can intercept a pass.
	-   `CanShoot()`: Samples goal mouth to find open shot angles.
	-   `FindPass()`: Evaluates teammates to find the best receiver.

#### `FieldPlayer`
-   **Role**: Autonomous agent playing on the field.
-   **FSM States**:
	-   `Wait`: Idle, waiting for ball or request.
	-   `ChaseBall`: Seeks the ball when closest.
	-   `Dribble`: Advances ball towards goal with small kicks.
	-   `KickBall`: Decides between Shooting, Passing (using `FindPass`), or Dribbling.
	-   `ReceiveBall`: Moves to intercept a pass.
	-   `SupportAttacker`: Moves to the Best Supporting Spot (BSS) to offer a passing option.
	-   `ReturnToHome`: Moves to assigned tactical region.

#### `Goalkeeper`
-   **Role**: Specialized agent protecting the goal.
-   **FSM States**:
	-   `TendGoal`: Moves along goal mouth to interpose ball.
	-   `InterceptBall`: Charges ball if within range.
	-   `PutBallBackInPlay`: Passes to nearest safe teammate after a save.
	-   `ReturnHome`: Returns to goal area.

#### `SupportSpotCalculator`
-   **Role**: Helper class owned by `SoccerTeam`.
-   **Logic**: Samples grid points on the pitch and scores them based on:
	-   Pass Safety (can the attacker pass here?)
	-   Shot Potential (can we shoot from here?)
	-   Optimal Distance (~200px from attacker)
	-   Upfield Advantage

## 🧠 Key Algorithms

### Interception Check (`IsPassSafeFromAllOpponents`)
Determines if a pass from A to B is safe.
1.  Transforms opponent positions into local space relative to the pass vector.
2.  Calculates time for ball to reach the point perpendicular to the opponent (`t_ball`).
3.  Calculates opponent's reachable distance in `t_ball` time.
4.  If opponent reach > distance to pass line, the pass is unsafe.

### Best Supporting Spot (BSS)
Evaluates potential positions for off-ball movement.
-   **Heuristic**: `Score = (PassSafe * 2.0) + (CanScore * 1.0) + (DistScore) + (UpfieldBonus)`
-   Visualized by a yellow circle and line in the debug view.

## 🎮 Controls & Visualization

-   **Run**: Open `concepts/04_soccer/soccer_demo.tscn`.
-   **Debug Draw**:
    -   **Regions**: Grid lines (optional).
    -   **Goals**: Colored boxes at pitch ends.
    -   **BSS**: Yellow circle + line to supporting player.
-   **Toggle Language**: Select root node -> `Use Csharp` checkbox.

## 📂 Directory Structure

-   `gdscript/`: Complete GDScript implementation.
-   `csharp/`: Complete C# implementation.
    -   `Scripts/`: (Optional) additional scripts.
-   `west_world/`: (Reference) Previous FSM implementation reused here.
