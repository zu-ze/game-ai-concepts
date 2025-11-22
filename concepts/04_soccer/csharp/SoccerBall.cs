using Godot;

namespace GameAI.Concepts.Soccer;

public partial class SoccerBall : RigidBody2D
{
    public const float FrictionMagnitude = 150.0f; // Deceleration

    public Vector2 OldPos { get; private set; }
    public Node2D OwnerPlayer { get; set; } = null;

    public override void _Ready()
    {
        GravityScale = 0; // Top-down
        LinearDamp = 0.0f; // Custom friction
        AngularDamp = 1.0f;
        
        ContactMonitor = true;
        MaxContactsReported = 4;
        
        // Collision Layer: 2 (Ball), Mask: 1 (Walls)
        CollisionLayer = 2;
        CollisionMask = 1;

        if (GetChildCount() == 0)
        {
            var col = new CollisionShape2D();
            var shape = new CircleShape2D();
            shape.Radius = 5.0f;
            col.Shape = shape;
            AddChild(col);

            var sprite = new Sprite2D();
            sprite.Texture = (Texture2D)GD.Load("res://icon.svg");
            sprite.Scale = new Vector2(0.1f, 0.1f);
            sprite.Modulate = Colors.White;
            AddChild(sprite);
        }
        
        OldPos = GlobalPosition;
    }

    public override void _IntegrateForces(PhysicsDirectBodyState2D state)
    {
        // Apply constant friction
        Vector2 vel = state.LinearVelocity;
        float speed = vel.Length();

        if (speed > 0)
        {
            float drop = FrictionMagnitude * state.Step;
            float newSpeed = Mathf.Max(0, speed - drop);
            state.LinearVelocity = vel.Normalized() * newSpeed;
        }

        OldPos = GlobalPosition;
    }

    public void Kick(Vector2 direction, float force)
    {
        direction = direction.Normalized();
        ApplyCentralImpulse(direction * force);
        OwnerPlayer = null;
    }

    public void Trap()
    {
        LinearVelocity = Vector2.Zero;
    }

    public Vector2 FuturePosition(float time)
    {
        float u = LinearVelocity.Length();
        float a = -FrictionMagnitude;

        float tStop = (FrictionMagnitude > 0) ? u / FrictionMagnitude : 9999.0f;
        float tCalc = Mathf.Min(time, tStop);

        float dist = u * tCalc + 0.5f * a * tCalc * tCalc;

        if (LinearVelocity.LengthSquared() > 0.001f)
        {
            return GlobalPosition + LinearVelocity.Normalized() * dist;
        }
        return GlobalPosition;
    }

    public float TimeToCoverDistance(Vector2 from, Vector2 to, float force)
    {
        // u = Force / Mass (assuming force is impulse)
        float u = force / Mass;
        float a = -FrictionMagnitude;
        float dist = from.DistanceTo(to);

        // v^2 = u^2 + 2*a*dist
        float term = u * u + 2 * a * dist;

        if (term <= 0) return -1.0f;

        float v = Mathf.Sqrt(term);

        if (Mathf.Abs(a) < 0.001f) return dist / u;

        return (v - u) / a;
    }
}
