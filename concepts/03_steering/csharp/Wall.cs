using Godot;

namespace GameAI.Concepts.Steering;

public class Wall
{
    public Vector2 From { get; set; }
    public Vector2 To { get; set; }
    public Vector2 Normal { get; set; }

    public Wall(Vector2 from, Vector2 to, Vector2? normal = null)
    {
        From = from;
        To = to;
        if (normal.HasValue)
        {
            Normal = normal.Value;
        }
        else
        {
            CalculateNormal();
        }
    }

    private void CalculateNormal()
    {
        Vector2 direction = (To - From).Normalized();
        Normal = new Vector2(-direction.Y, direction.X); // Left normal
    }
}
