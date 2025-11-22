using Godot;
using System.Collections.Generic;

namespace GameAI.Concepts.Soccer;

public partial class SoccerTeam : Node2D
{
    public enum TeamColor { Red, Blue }

    public TeamColor Color { get; set; }
    public List<PlayerBase> Players { get; set; } = new List<PlayerBase>();
    public SoccerPitch Pitch { get; set; }
    public Goal HomeGoal { get; set; }
    public Goal OpponentsGoal { get; set; }

    // Tactical
    public PlayerBase ControllingPlayer { get; set; }
    public PlayerBase SupportingPlayer { get; set; }
    public PlayerBase Receiver { get; set; }
    public PlayerBase ClosestPlayerToBall { get; set; }

    public SoccerTeam() { } // Default constructor

    public SoccerTeam(SoccerPitch pitch, TeamColor color, Goal homeGoal, Goal opponentsGoal)
    {
        Pitch = pitch;
        Color = color;
        HomeGoal = homeGoal;
        OpponentsGoal = opponentsGoal;
    }

    public override void _Ready()
    {
        CreatePlayers();
    }

    private void CreatePlayers()
    {
        if (Color == TeamColor.Red)
        {
            AddPlayer<Goalkeeper>(4);
            AddPlayer<FieldPlayer>(1);
            AddPlayer<FieldPlayer>(9);
            AddPlayer<FieldPlayer>(6);
            AddPlayer<FieldPlayer>(7);
        }
        else
        {
            AddPlayer<Goalkeeper>(7);
            AddPlayer<FieldPlayer>(2);
            AddPlayer<FieldPlayer>(10);
            AddPlayer<FieldPlayer>(5);
            AddPlayer<FieldPlayer>(4);
        }
    }

    private void AddPlayer<T>(int regionId) where T : PlayerBase, new()
    {
        // In C# we can't pass arguments to new() if using generic constraint new() 
        // easily with specific constructor.
        // So we instantiate and then set properties or use a factory method.
        var p = new T();
        // Manually initializing since we can't use constructor with new()
        p.Team = this;
        p.HomeRegion = regionId;
        p.DefaultRegion = regionId;
        p.Mass = 70.0f;
        p.MaxSpeed = 150.0f;
        p.MaxForce = 100.0f;
        p.MaxTurnRate = 5.0f;
        
        p.Position = Pitch.Regions[regionId].Center;

        var sprite = new Sprite2D();
        sprite.Texture = (Texture2D)GD.Load("res://icon.svg");
        sprite.Scale = new Vector2(0.3f, 0.3f);
        sprite.Modulate = Color == TeamColor.Red ? Colors.Red : Colors.Blue;
        p.AddChild(sprite);

        Players.Add(p);
        AddChild(p);
    }

    public override void _Process(double delta)
    {
        UpdateClosestPlayerToBall();
        CheckBallControl();
    }

    private void UpdateClosestPlayerToBall()
    {
        float closestDist = float.MaxValue;
        ClosestPlayerToBall = null;

        foreach (var p in Players)
        {
            float d = p.GlobalPosition.DistanceSquaredTo(Pitch.Ball.GlobalPosition);
            if (d < closestDist)
            {
                closestDist = d;
                ClosestPlayerToBall = p;
            }
        }
    }

    private void CheckBallControl()
    {
        ControllingPlayer = null;
        float distThreshold = 20.0f * 20.0f;

        if (ClosestPlayerToBall != null)
        {
            if (ClosestPlayerToBall.GlobalPosition.DistanceSquaredTo(Pitch.Ball.GlobalPosition) < distThreshold)
            {
                ControllingPlayer = ClosestPlayerToBall;
                Pitch.Ball.OwnerPlayer = ControllingPlayer;
                Pitch.Ball.Trap();
            }
        }
    }
}
