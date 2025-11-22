using Godot;
using System.Collections.Generic;
using GameAI.Concepts.Steering;

namespace GameAI.Concepts.Soccer;

public partial class SoccerPitch : Node2D
{
    public SoccerBall Ball { get; private set; }
    public Goal RedGoal { get; private set; }
    public Goal BlueGoal { get; private set; }
    
    // public SoccerTeam RedTeam { get; set; }
    // public SoccerTeam BlueTeam { get; set; }

    public Dictionary<int, Region> Regions { get; private set; } = new Dictionary<int, Region>();
    public List<Wall> Walls { get; private set; } = new List<Wall>();

    public float PitchWidth { get; set; } = 800.0f;
    public float PitchHeight { get; set; } = 500.0f;

    public override void _Ready()
    {
        RedGoal = new Goal(new Vector2(40, 180), new Vector2(40, 320), new Vector2(1, 0));
        BlueGoal = new Goal(new Vector2(760, 180), new Vector2(760, 320), new Vector2(-1, 0));

        Ball = new SoccerBall();
        Ball.Position = new Vector2(PitchWidth / 2, PitchHeight / 2);
        AddChild(Ball);

        CreateWalls();
        CreateRegions(4, 3);
    }

    private void CreateWalls()
    {
        Walls.Add(new Wall(new Vector2(0, 0), new Vector2(PitchWidth, 0))); // Top
        Walls.Add(new Wall(new Vector2(PitchWidth, PitchHeight), new Vector2(0, PitchHeight))); // Bottom
        Walls.Add(new Wall(new Vector2(0, PitchHeight), new Vector2(0, 320))); // Bottom-Left
        Walls.Add(new Wall(new Vector2(0, 180), new Vector2(0, 0))); // Top-Left
        Walls.Add(new Wall(new Vector2(PitchWidth, 0), new Vector2(PitchWidth, 180))); // Top-Right
        Walls.Add(new Wall(new Vector2(PitchWidth, 320), new Vector2(PitchWidth, PitchHeight))); // Bottom-Right
        
        QueueRedraw();
    }

    private void CreateRegions(int cols, int rows)
    {
        float cellW = PitchWidth / cols;
        float cellH = PitchHeight / rows;
        int id = 0;
        for (int y = 0; y < rows; y++)
        {
            for (int x = 0; x < cols; x++)
            {
                var r = new Region(x * cellW, y * cellH, (x + 1) * cellW, (y + 1) * cellH, id);
                Regions[id] = r;
                id++;
            }
        }
    }

    public override void _Process(double delta)
    {
        if (RedGoal.CheckScore(Ball))
        {
            GD.Print("Blue Team Scored!");
            ResetBall();
        }

        if (BlueGoal.CheckScore(Ball))
        {
            GD.Print("Red Team Scored!");
            ResetBall();
        }
    }

    private void ResetBall()
    {
        Ball.Position = new Vector2(PitchWidth / 2, PitchHeight / 2);
        Ball.Trap();
    }

    public override void _Draw()
    {
        DrawRect(new Rect2(0, 0, PitchWidth, PitchHeight), Colors.ForestGreen);
        DrawLine(new Vector2(PitchWidth / 2, 0), new Vector2(PitchWidth / 2, PitchHeight), Colors.White, 2.0f);
        DrawCircle(new Vector2(PitchWidth / 2, PitchHeight / 2), 50.0f, Colors.White, false, 2.0f);
        DrawRect(new Rect2(0, 180, 40, 140), new Color(1, 0.5f, 0.5f, 0.5f));
        DrawRect(new Rect2(760, 180, 40, 140), new Color(0.5f, 0.5f, 1, 0.5f));
    }
}
