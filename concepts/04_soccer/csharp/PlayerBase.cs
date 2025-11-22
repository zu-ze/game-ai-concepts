using Godot;
using GameAI.Concepts.Steering;

namespace GameAI.Concepts.Soccer;

public partial class PlayerBase : Vehicle
{
    public SoccerTeam Team { get; set; }
    public int HomeRegion { get; set; }
    public int DefaultRegion { get; set; }

    public PlayerBase() { } // Default constructor required for Godot if instantiated via Scene

    public PlayerBase(SoccerTeam team, int homeRegion, float mass, float maxSpeed, float maxForce, float maxTurnRate)
    {
        Team = team;
        HomeRegion = homeRegion;
        DefaultRegion = homeRegion;
        Mass = mass;
        MaxSpeed = maxSpeed;
        MaxForce = maxForce;
        MaxTurnRate = maxTurnRate;
    }

    public bool IsClosestTeamMemberToBall()
    {
        return Team.ClosestPlayerToBall == this;
    }

    public bool IsControllingBall()
    {
        return Team.ControllingPlayer == this;
    }
}
