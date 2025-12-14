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
	public override void Execute(BaseGameEntity entity) 
	{ 
		var p = (FieldPlayer)entity;
		if (p.IsControllingBall())
			p.MaxSpeed = 100.0f;
		else
			p.MaxSpeed = 150.0f;
	}
	public override void Exit(BaseGameEntity entity) { }
	public override bool OnMessage(BaseGameEntity entity, Telegram telegram) 
	{ 
		var p = (FieldPlayer)entity;
		if (telegram.Msg == MessageTypes.GoHome)
		{
			p.Steering.TargetPos = p.Team.Pitch.Regions[p.HomeRegion].Center;
			p.StateMachine.ChangeState(new ReturnToHome());
			return true;
		}
		else if (telegram.Msg == MessageTypes.ReceiveBall)
		{
			Vector2 target = (Vector2)telegram.ExtraInfo["target"];
			p.Steering.TargetPos = target;
			p.StateMachine.ChangeState(new ReceiveBall());
			return true;
		}
		else if (telegram.Msg == MessageTypes.SupportAttacker)
		{
			if (!p.IsControllingBall())
			{
				p.StateMachine.ChangeState(new SupportAttacker());
				return true;
			}
		}
		else if (telegram.Msg == MessageTypes.Wait)
		{
			p.StateMachine.ChangeState(new Wait());
			return true;
		}
		else if (telegram.Msg == MessageTypes.PassToMe)
		{
			var receiver = telegram.Sender as FieldPlayer;
			if (p.IsControllingBall() && receiver != null)
			{
				Vector2 kickTarget = receiver.GlobalPosition;
				p.Team.Pitch.Ball.Kick(kickTarget - p.GlobalPosition, 250.0f);
				p.Team.Receiver = receiver;
				
				var info = new Godot.Collections.Dictionary();
				info["target"] = kickTarget;
				MessageDispatcher.Instance.DispatchMessage(0, p, receiver, MessageTypes.ReceiveBall, info);
				
				p.StateMachine.ChangeState(new Wait());
			}
			return true;
		}
		return false; 
	}
}

public class Wait : State<BaseGameEntity>
{
	public override void Enter(BaseGameEntity entity)
	{
		var p = (FieldPlayer)entity;
		p.Velocity = Vector2.Zero;
		p.Steering.AllOff();
	}

	public override void Execute(BaseGameEntity entity)
	{
		var p = (FieldPlayer)entity;
		if (p.IsClosestTeamMemberToBall() && 
			p.Team.Receiver != p && 
			p.Team.Pitch.Ball.OwnerPlayer == null)
		{
			p.StateMachine.ChangeState(new ChaseBall());
			return;
		}
		
		// Request pass
		if (p.Team.ControllingPlayer != null && !p.IsControllingBall())
		{
			float distToGoal = p.GlobalPosition.DistanceSquaredTo(p.Team.OpponentsGoal.Center);
			float controllerDist = p.Team.ControllingPlayer.GlobalPosition.DistanceSquaredTo(p.Team.OpponentsGoal.Center);
			if (distToGoal < controllerDist)
			{
				p.Team.RequestPass(p);
			}
		}
	}
	
	public override void Exit(BaseGameEntity entity) { }
	public override bool OnMessage(BaseGameEntity entity, Telegram telegram) { return false; }
}

public class ReceiveBall : State<BaseGameEntity>
{
	public override void Enter(BaseGameEntity entity)
	{
		var p = (FieldPlayer)entity;
		p.Steering.ArriveOn();
	}

	public override void Execute(BaseGameEntity entity)
	{
		var p = (FieldPlayer)entity;
		if (p.IsClosestTeamMemberToBall() && 
			p.GlobalPosition.DistanceSquaredTo(p.Team.Pitch.Ball.GlobalPosition) < 400)
		{
			p.StateMachine.ChangeState(new ChaseBall());
			return;
		}

		if (p.Team.ControllingPlayer == null && p.Team.Receiver != p)
		{
			p.StateMachine.ChangeState(new ChaseBall());
		}
	}

	public override void Exit(BaseGameEntity entity)
	{
		var p = (FieldPlayer)entity;
		p.Steering.ArriveOff();
		p.Team.Receiver = null;
	}
	public override bool OnMessage(BaseGameEntity entity, Telegram telegram) { return false; }
}

public class ChaseBall : State<BaseGameEntity>
{
	public override void Enter(BaseGameEntity entity)
	{
		var p = (FieldPlayer)entity;
		p.Steering.SeekOn();
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
		p.Steering.SeekOff();
	}
	public override bool OnMessage(BaseGameEntity entity, Telegram telegram) { return false; }
}

public class Dribble : State<BaseGameEntity>
{
	public override void Enter(BaseGameEntity entity)
	{
		var p = (FieldPlayer)entity;
		p.Team.ControllingPlayer = p;
		p.Steering.AllOff();
	}

	public override void Execute(BaseGameEntity entity)
	{
		var p = (FieldPlayer)entity;
		var ball = p.Team.Pitch.Ball;
		var goalDir = (p.Team.OpponentsGoal.Center - p.GlobalPosition).Normalized();
		float dot = p.Heading.Dot(goalDir);

		if (dot < 0.9f)
		{
			ball.Kick(goalDir, 5.0f);
		}
		else
		{
			ball.Kick(p.Heading, 10.0f);
		}
		p.StateMachine.ChangeState(new ChaseBall());
	}

	public override void Exit(BaseGameEntity entity) { }
	public override bool OnMessage(BaseGameEntity entity, Telegram telegram) { return false; }
}

public class KickBall : State<BaseGameEntity>
{
	public override void Enter(BaseGameEntity entity)
	{
		var p = (FieldPlayer)entity;
		p.Velocity = Vector2.Zero;
		p.Steering.AllOff();
		p.Team.ControllingPlayer = p;
	}

	public override void Execute(BaseGameEntity entity)
	{
		var p = (FieldPlayer)entity;
		var ball = p.Team.Pitch.Ball;
		var toBall = ball.GlobalPosition - p.GlobalPosition;
		float dot = p.Heading.Dot(toBall.Normalized());

		if (dot < 0) 
		{
			p.StateMachine.ChangeState(new ChaseBall());
			return;
		}

		float shotPower = 300.0f;
		var shotInfo = p.Team.CanShoot(p.GlobalPosition, shotPower);
		if (shotInfo.CanShoot)
		{
			ball.Kick(shotInfo.Target - p.GlobalPosition, shotPower);
			p.StateMachine.ChangeState(new Wait());
			return;
		}

		var passInfo = p.Team.FindPass(p, 250.0f);
		if (passInfo.Success)
		{
			var receiver = passInfo.Receiver;
			var target = passInfo.Target;
			
			ball.Kick(target - p.GlobalPosition, 250.0f);
			p.Team.Receiver = receiver;
			
			var info = new Godot.Collections.Dictionary();
			info["target"] = target;
			MessageDispatcher.Instance.DispatchMessage(0, p, receiver, MessageTypes.ReceiveBall, info);
			
			p.StateMachine.ChangeState(new Wait());
			return;
		}

		p.StateMachine.ChangeState(new Dribble());
	}

	public override void Exit(BaseGameEntity entity) { }
	public override bool OnMessage(BaseGameEntity entity, Telegram telegram) { return false; }
}

public class SupportAttacker : State<BaseGameEntity>
{
	public override void Enter(BaseGameEntity entity)
	{
		var p = (FieldPlayer)entity;
		p.Steering.ArriveOn();
		p.Steering.TargetPos = p.Team.GetSupportSpot();
	}

	public override void Execute(BaseGameEntity entity)
	{
		var p = (FieldPlayer)entity;
		
		if (p.Team.ControllingPlayer == null)
		{
			p.StateMachine.ChangeState(new ReturnToHome());
			return;
		}

		Vector2 bss = p.Team.GetSupportSpot();
		if (bss != p.Steering.TargetPos)
		{
			p.Steering.TargetPos = bss;
		}

		if (p.GlobalPosition.DistanceSquaredTo(bss) < 100)
		{
			p.Velocity = Vector2.Zero;
			p.Steering.AllOff();

			if (!p.IsThreatened() && p.Team.CanShoot(p.GlobalPosition, 300.0f).CanShoot)
			{
				p.Team.RequestPass(p);
			}
		}
	}

	public override void Exit(BaseGameEntity entity)
	{
		var p = (FieldPlayer)entity;
		p.Steering.AllOff();
	}
	public override bool OnMessage(BaseGameEntity entity, Telegram telegram) { return false; }
}

public class ReturnToHome : State<BaseGameEntity>
{
	public override void Enter(BaseGameEntity entity)
	{
		var p = (FieldPlayer)entity;
		p.Steering.ArriveOn();
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
		p.Steering.ArriveOff();
	}
	public override bool OnMessage(BaseGameEntity entity, Telegram telegram) { return false; }
}
