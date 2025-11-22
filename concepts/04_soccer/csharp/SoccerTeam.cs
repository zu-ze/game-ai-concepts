using Godot;
using System.Collections.Generic;

using GameAI.Concepts.FSM;

namespace GameAI.Concepts.Soccer;

public partial class SoccerTeam : Node2D
{
    public enum TeamColor { Red, Blue }

    public TeamColor Color { get; set; }
    public List<PlayerBase> Players { get; set; } = new List<PlayerBase>();
    public SoccerPitch Pitch { get; set; }
    public Goal HomeGoal { get; set; }
    public Goal OpponentsGoal { get; set; }
    
    public StateMachine<SoccerTeam> StateMachine { get; set; }
    public SupportSpotCalculator SupportSpotCalculator { get; private set; }

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
        SupportSpotCalculator = new SupportSpotCalculator(this);
    }

    public override void _Ready()
    {
        CreatePlayers();
        StateMachine = new StateMachine<SoccerTeam>(this);
        StateMachine.SetCurrentState(new PrepareForKickOff());
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
        StateMachine.Update();
        UpdateSupportSpot();
    }

    private void UpdateSupportSpot()
    {
        if (ControllingPlayer != null)
        {
            Vector2 bestSpot = SupportSpotCalculator.DetermineBestSupportingSpot();
            DetermineSupportingPlayer(bestSpot);
            QueueRedraw();
        }
        else
        {
            SupportingPlayer = null;
            QueueRedraw();
        }
    }

    private void DetermineSupportingPlayer(Vector2 bestSpot)
    {
        float closestDist = float.MaxValue;
        PlayerBase bestPlayer = null;

        foreach (var p in Players)
        {
            if (p is FieldPlayer && p != ControllingPlayer)
            {
                float d = p.GlobalPosition.DistanceSquaredTo(bestSpot);
                if (d < closestDist)
                {
                    closestDist = d;
                    bestPlayer = p;
                }
            }
        }
        SupportingPlayer = bestPlayer;
    }

    public override void _Draw()
    {
        if (SupportingPlayer != null)
        {
            DrawCircle(SupportSpotCalculator.BestSupportingSpot, 10.0f, Colors.Yellow);
            DrawLine(SupportingPlayer.GlobalPosition, SupportSpotCalculator.BestSupportingSpot, Colors.Yellow, 1.0f);
        }
    }

    public void SetPlayerHomeRegion(int playerIdx, int regionId)
    {
        if (playerIdx >= 0 && playerIdx < Players.Count)
        {
            Players[playerIdx].HomeRegion = regionId;
        }
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

    public bool IsPassSafeFromAllOpponents(Vector2 from, Vector2 to, PlayerBase receiver, float passForce)
    {
        Vector2 rayDir = (to - from).Normalized();
        Vector2 localX = rayDir;
        Vector2 localY = rayDir.Orthogonal();

        var opponents = (Color == TeamColor.Red) ? Pitch.BlueTeam.Players : Pitch.RedTeam.Players;

        foreach (var opp in opponents)
        {
            Vector2 toOpp = opp.GlobalPosition - from;
            float oppLocalX = toOpp.Dot(localX);
            float oppLocalY = toOpp.Dot(localY);

            if (oppLocalX < 0) continue;

            Vector2 interceptPoint = from + rayDir * oppLocalX;
            float tBall = Pitch.Ball.TimeToCoverDistance(from, interceptPoint, passForce);

            if (tBall < 0) continue;

            float ballRadius = 5.0f;
            float oppRadius = opp.BoundingRadius;
            float reach = (opp.MaxSpeed * tBall) + ballRadius + oppRadius;

            if (Mathf.Abs(oppLocalY) < reach) return false;
        }
        return true;
    }

    public struct ShotResult
    {
        public bool CanShoot;
        public Vector2 Target;
    }

    public ShotResult CanShoot(Vector2 from, float power)
    {
        // Check center
        if (IsPassSafeFromAllOpponents(from, OpponentsGoal.Center, null, power))
        {
            return new ShotResult { CanShoot = true, Target = OpponentsGoal.Center };
        }

        // Sample
        int numSamples = 5;
        for (int i = 0; i < numSamples; i++)
        {
            float t = GD.Randf();
            Vector2 target = OpponentsGoal.LeftPost.Lerp(OpponentsGoal.RightPost, t);
            if (IsPassSafeFromAllOpponents(from, target, null, power))
            {
                return new ShotResult { CanShoot = true, Target = target };
            }
        }

        return new ShotResult { CanShoot = false, Target = Vector2.Zero };
    }

    public struct PassResult
    {
        public bool Success;
        public PlayerBase Receiver;
        public Vector2 Target;
    }

    public PassResult FindPass(PlayerBase passer, float power, float minPassingDist = 50.0f)
    {
        PassResult bestResult = new PassResult { Success = false };
        float bestScore = -1.0f;

        foreach (var p in Players)
        {
            if (p == passer) continue;
            if (passer.GlobalPosition.DistanceTo(p.GlobalPosition) < minPassingDist) continue;

            var info = GetBestPassToReceiver(passer, p, power);
            if (info.Success)
            {
                float score = (Color == TeamColor.Red) ? info.Target.X : (Pitch.PitchWidth - info.Target.X);
                if (score > bestScore)
                {
                    bestScore = score;
                    bestResult = new PassResult { Success = true, Receiver = p, Target = info.Target };
                }
            }
        }
        return bestResult;
    }

    public struct PassInfo
    {
        public bool Success;
        public Vector2 Target;
    }

    public PassInfo GetBestPassToReceiver(PlayerBase passer, PlayerBase receiver, float power)
    {
        if (IsPassSafeFromAllOpponents(passer.GlobalPosition, receiver.GlobalPosition, receiver, passForce: power))
        {
            return new PassInfo { Success = true, Target = receiver.GlobalPosition };
        }
        return new PassInfo { Success = false };
    }

    public void RequestPass(PlayerBase requester)
    {
        if (ControllingPlayer != null && ControllingPlayer != requester)
        {
            MessageDispatcher.Instance.DispatchMessage(0, requester, ControllingPlayer, MessageTypes.PassToMe);
        }
    }

    public Vector2 GetSupportSpot()
    {
        return SupportSpotCalculator.BestSupportingSpot;
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

public class TeamDefending : State<SoccerTeam>
{
    public override void Enter(SoccerTeam team)
    {
        GD.Print(team.Name + " entering Defending state");
        if (team.Color == SoccerTeam.TeamColor.Red)
        {
            team.SetPlayerHomeRegion(1, 1); 
            team.SetPlayerHomeRegion(2, 9); 
            team.SetPlayerHomeRegion(3, 5); 
            team.SetPlayerHomeRegion(4, 6); 
        }
        else
        {
            team.SetPlayerHomeRegion(1, 2);
            team.SetPlayerHomeRegion(2, 10);
            team.SetPlayerHomeRegion(3, 6);
            team.SetPlayerHomeRegion(4, 5);
        }
    }

    public override void Execute(SoccerTeam team)
    {
        if (team.ControllingPlayer != null)
        {
            team.StateMachine.ChangeState(new TeamAttacking());
        }
    }

    public override void Exit(SoccerTeam team) { }
    public override bool OnMessage(SoccerTeam team, Telegram telegram) { return false; }
}

public class TeamAttacking : State<SoccerTeam>
{
    public override void Enter(SoccerTeam team)
    {
        GD.Print(team.Name + " entering Attacking state");
        if (team.Color == SoccerTeam.TeamColor.Red)
        {
            team.SetPlayerHomeRegion(1, 5); 
            team.SetPlayerHomeRegion(2, 8); 
            team.SetPlayerHomeRegion(3, 6); 
            team.SetPlayerHomeRegion(4, 7); 
        }
        else
        {
            team.SetPlayerHomeRegion(1, 6);
            team.SetPlayerHomeRegion(2, 3);
            team.SetPlayerHomeRegion(3, 5);
            team.SetPlayerHomeRegion(4, 4);
        }
    }

    public override void Execute(SoccerTeam team)
    {
        if (team.ControllingPlayer == null)
        {
            team.StateMachine.ChangeState(new TeamDefending());
        }
    }

    public override void Exit(SoccerTeam team) { }
    public override bool OnMessage(SoccerTeam team, Telegram telegram) { return false; }
}
