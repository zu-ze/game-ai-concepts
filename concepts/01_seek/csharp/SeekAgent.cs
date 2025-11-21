using Godot;
using System;

namespace GameAI.Concepts.Seek;

public partial class SeekAgent : CharacterBody2D
{
    [Export]
    public float Speed { get; set; } = 200.0f;

    [Export]
    public Node2D Target { get; set; }

    public override void _PhysicsProcess(double delta)
    {
        if (Target != null)
        {
            // Calculate direction vector from current position to target position
            Vector2 direction = GlobalPosition.DirectionTo(Target.GlobalPosition);

            // Set velocity
            Velocity = direction * Speed;

            // Apply movement
            MoveAndSlide();

            // Optional: Rotate towards target
            LookAt(Target.GlobalPosition);
        }
    }
}
