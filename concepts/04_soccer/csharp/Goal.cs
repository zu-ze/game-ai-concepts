using Godot;

namespace GameAI.Concepts.Soccer;

public class Goal
{
    public Vector2 LeftPost { get; set; }
    public Vector2 RightPost { get; set; }
    public Vector2 FacingDirection { get; set; }
    public Vector2 Center { get; set; }
    public int ScoredCount { get; set; } = 0;

    public Goal(Vector2 left, Vector2 right, Vector2 facing)
    {
        LeftPost = left;
        RightPost = right;
        FacingDirection = facing;
        Center = (LeftPost + RightPost) / 2.0f;
    }

    public bool CheckScore(RigidBody2D ball)
    {
        if (FacingDirection.X > 0) // Left Goal
        {
            if (ball.GlobalPosition.X < Center.X && ball.GlobalPosition.Y > LeftPost.Y && ball.GlobalPosition.Y < RightPost.Y)
                return true;
        }
        else // Right Goal
        {
            if (ball.GlobalPosition.X > Center.X && ball.GlobalPosition.Y > LeftPost.Y && ball.GlobalPosition.Y < RightPost.Y)
                return true;
        }
        return false;
    }
}
