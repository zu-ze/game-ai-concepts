using Godot;
using GameAI.Concepts.Steering;
using GameAI.Concepts.FSM;

namespace GameAI.Concepts.Soccer;

public partial class FieldPlayer : PlayerBase
{
    public FieldPlayer() { }
    public FieldPlayer(SoccerTeam team, int homeRegion, float mass, float maxSpeed, float maxForce, float maxTurnRate) 
        : base(team, homeRegion, mass, maxSpeed, maxForce, maxTurnRate) { }

    public override void _Ready()
    {
        base._Ready();
        StateMachine.SetCurrentState(new Wait());
        StateMachine.SetGlobalState(new FieldPlayerGlobalState());
    }
}

// States

public class FieldPlayerGlobalState : State<BaseGameEntity>
{
    public override void Enter(BaseGameEntity entity) { }
    public override void Execute(BaseGameEntity entity) { }
    public override void Exit(BaseGameEntity entity) { }
    public override bool OnMessage(BaseGameEntity entity, Telegram telegram) { return false; }
}

public class Wait : State<BaseGameEntity>
{
    public override void Enter(BaseGameEntity entity)
    {
        var p = (FieldPlayer)entity;
        p.Velocity = Vector2.Zero;
        p.Steering.Flags = 0;
    }

    public override void Execute(BaseGameEntity entity)
    {
        var p = (FieldPlayer)entity;
        if (p.IsClosestTeamMemberToBall() && 
            p.Team.Receiver != p && 
            p.Team.Pitch.Ball.OwnerPlayer == null)
        {
            p.StateMachine.ChangeState(new ChaseBall());
        }
    }
    
    public override void Exit(BaseGameEntity entity) { }
    public override bool OnMessage(BaseGameEntity entity, Telegram telegram) { return false; }
}

public class ChaseBall : State<BaseGameEntity>
{
    public override void Enter(BaseGameEntity entity)
    {
        var p = (FieldPlayer)entity;
        p.Steering.Flags = SteeringBehaviors.BehaviorType.Seek;
    }

    public override void Execute(BaseGameEntity entity)
    {
        var p = (FieldPlayer)entity;
        p.Steering.TargetPos = p.Team.Pitch.Ball.Position;

        if (p.IsControllingBall())
        {
            p.StateMachine.ChangeState(new KickBall());
            return;
        }

        if (!p.IsClosestTeamMemberToBall())
        {
            p.StateMachine.ChangeState(new ReturnToHome());
        }
    }

    public override void Exit(BaseGameEntity entity)
    {
        var p = (FieldPlayer)entity;
        p.Steering.Flags = 0;
    }
    public override bool OnMessage(BaseGameEntity entity, Telegram telegram) { return false; }
}

public class KickBall : State<BaseGameEntity>
{
    public override void Enter(BaseGameEntity entity)
    {
        var p = (FieldPlayer)entity;
        p.Velocity = Vector2.Zero;
    }

    public override void Execute(BaseGameEntity entity)
    {
        var p = (FieldPlayer)entity;
        Vector2 target = p.Team.OpponentsGoal.Center;
        p.Team.Pitch.Ball.Kick(target - p.GlobalPosition, 200.0f);
        p.StateMachine.ChangeState(new Wait());
    }

    public override void Exit(BaseGameEntity entity) { }
    public override bool OnMessage(BaseGameEntity entity, Telegram telegram) { return false; }
}

public class ReturnToHome : State<BaseGameEntity>
{
    public override void Enter(BaseGameEntity entity)
    {
        var p = (FieldPlayer)entity;
        p.Steering.Flags = SteeringBehaviors.BehaviorType.Arrive;
    }

    public override void Execute(BaseGameEntity entity)
    {
        var p = (FieldPlayer)entity;
        var region = p.Team.Pitch.Regions[p.HomeRegion];
        p.Steering.TargetPos = region.Center;

        if (p.IsClosestTeamMemberToBall() && p.Team.Pitch.Ball.OwnerPlayer == null)
        {
            p.StateMachine.ChangeState(new ChaseBall());
            return;
        }

        if (p.GlobalPosition.DistanceSquaredTo(region.Center) < 100)
        {
            p.StateMachine.ChangeState(new Wait());
        }
    }

    public override void Exit(BaseGameEntity entity)
    {
        var p = (FieldPlayer)entity;
        p.Steering.Flags = 0;
    }
    public override bool OnMessage(BaseGameEntity entity, Telegram telegram) { return false; }
}
