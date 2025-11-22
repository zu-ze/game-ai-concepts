using Godot;

namespace GameAI.Concepts.Soccer;

public partial class SoccerBall : RigidBody2D
{
    public Vector2 OldPos { get; private set; }
    public Node2D OwnerPlayer { get; set; } = null;

    public override void _Ready()
    {
        GravityScale = 0; // Top-down
        LinearDamp = 1.0f; // Friction
        ContactMonitor = true;
        MaxContactsReported = 4;

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
        return GlobalPosition + LinearVelocity * time;
    }

    public float TimeToCoverDistance(Vector2 from, Vector2 to, float force)
    {
        float speed = force; 
        if (speed <= 0) return 1000.0f;
        return from.DistanceTo(to) / speed;
    }
}
