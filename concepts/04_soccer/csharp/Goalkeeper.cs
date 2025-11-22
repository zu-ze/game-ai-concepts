using Godot;
using GameAI.Concepts.Steering;
using GameAI.Concepts.FSM;

namespace GameAI.Concepts.Soccer;

public partial class Goalkeeper : PlayerBase
{
    public Goalkeeper() { }
    public Goalkeeper(SoccerTeam team, int homeRegion, float mass, float maxSpeed, float maxForce, float maxTurnRate) 
        : base(team, homeRegion, mass, maxSpeed, maxForce, maxTurnRate) { }

    public override void _Ready()
    {
        base._Ready();
        StateMachine.SetCurrentState(new TendGoal());
    }
}

// States

public class TendGoal : State<BaseGameEntity>
{
    public override void Enter(BaseGameEntity entity)
    {
        var p = (Goalkeeper)entity;
        p.Steering.ArriveOn();
    }

    public override void Execute(BaseGameEntity entity)
    {
        var p = (Goalkeeper)entity;
        var ball = p.Team.Pitch.Ball;
        var goalCenter = p.Team.HomeGoal.Center;

        Vector2 target = (ball.GlobalPosition + goalCenter) / 2.0f;
        target.Y = Mathf.Clamp(target.Y, p.Team.HomeGoal.LeftPost.Y, p.Team.HomeGoal.RightPost.Y);
        target.X = goalCenter.X + (p.Team.HomeGoal.FacingDirection.X * 20.0f);

        p.Steering.TargetPos = target;

        if (ball.GlobalPosition.DistanceSquaredTo(p.GlobalPosition) < 4000)
        {
            p.StateMachine.ChangeState(new InterceptBall());
        }
    }

    public override void Exit(BaseGameEntity entity)
    {
        var p = (Goalkeeper)entity;
        p.Steering.ArriveOff();
    }
    public override bool OnMessage(BaseGameEntity entity, Telegram telegram) { return false; }
}

public class InterceptBall : State<BaseGameEntity>
{
    public override void Enter(BaseGameEntity entity)
    {
        var p = (Goalkeeper)entity;
        p.Steering.ArriveOn();
    }

    public override void Execute(BaseGameEntity entity)
    {
        var p = (Goalkeeper)entity;
        p.Steering.TargetPos = p.Team.Pitch.Ball.GlobalPosition;

        if (p.GlobalPosition.DistanceSquaredTo(p.Team.Pitch.Ball.GlobalPosition) < 400)
        {
            p.Team.Pitch.Ball.Trap();
            p.Team.Pitch.Ball.OwnerPlayer = p;
            p.StateMachine.ChangeState(new PutBallBackInPlay());
        }
    }

    public override void Exit(BaseGameEntity entity)
    {
        var p = (Goalkeeper)entity;
        p.Steering.AllOff();
    }
    public override bool OnMessage(BaseGameEntity entity, Telegram telegram) { return false; }
}

public class PutBallBackInPlay : State<BaseGameEntity>
{
    public override void Enter(BaseGameEntity entity)
    {
        var p = (Goalkeeper)entity;
        p.Velocity = Vector2.Zero;
    }

    public override void Execute(BaseGameEntity entity)
    {
        var p = (Goalkeeper)entity;
        Vector2 direction = new Vector2(-p.Team.HomeGoal.FacingDirection.X, 0);
        p.Team.Pitch.Ball.Kick(direction, 300.0f);
        p.StateMachine.ChangeState(new TendGoal());
    }

    public override void Exit(BaseGameEntity entity) { }
    public override bool OnMessage(BaseGameEntity entity, Telegram telegram) { return false; }
}
