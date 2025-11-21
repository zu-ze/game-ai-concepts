using Godot;
using GameAI.Concepts.FSM; // Assuming we inherit from BaseGameEntity

namespace GameAI.Concepts.Steering;

public partial class Vehicle : BaseGameEntity
{
    [Export] public float MaxSpeed { get; set; } = 150.0f;
    [Export] public float MaxForce { get; set; } = 100.0f;
    [Export] public float Mass { get; set; } = 1.0f;
    [Export] public float MaxTurnRate { get; set; } = 5.0f;

    public SteeringBehaviors Steering { get; private set; }
    public Vector2 Heading { get; private set; } = Vector2.Right;
    public Vector2 Side { get; private set; } = Vector2.Down;

    public override void _Ready()
    {
        base._Ready();
        Steering = new SteeringBehaviors(this);
    }

    public override void _PhysicsProcess(double delta)
    {
        base._PhysicsProcess(delta);

        Vector2 steeringForce = Steering.Calculate((float)delta);
        Vector2 acceleration = steeringForce / Mass;

        Velocity += acceleration * (float)delta;

        if (Velocity.Length() > MaxSpeed)
        {
            Velocity = Velocity.Normalized() * MaxSpeed;
        }

        if (Velocity.LengthSquared() > 0.0001f)
        {
            Heading = Velocity.Normalized();
            Side = Heading.Orthogonal();
            Rotation = Heading.Angle();
        }

        MoveAndSlide();
    }
}
