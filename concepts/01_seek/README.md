# Seek Behavior

## Description
The Seek behavior is a fundamental steering behavior where an agent moves towards a specific target position. It calculates a velocity vector pointing from the agent's current position to the target's position.

## Implementation

### GDScript
- **Location**: `gdscript/seek_agent.gd`
- **Type**: `CharacterBody2D`
- **Usage**: 
    1. Attach `seek_agent.gd` to a `CharacterBody2D` node.
    2. Assign a `Node2D` (like a Marker2D or another body) to the `Target` export property in the Inspector.
    3. Adjust `Speed` as needed.

### C#
- **Location**: `csharp/SeekAgent.cs`
- **Type**: `CharacterBody2D`
- **Usage**:
    1. Attach `SeekAgent.cs` to a `CharacterBody2D` node.
    2. Build the project to ensure the C# class is recognized.
    3. Assign a `Node2D` to the `Target` export property.

## Logic
The core logic involves:
1. Calculating the direction: `(target_pos - current_pos).normalized()`
2. Setting velocity: `direction * speed`
3. Moving: `move_and_slide()`
