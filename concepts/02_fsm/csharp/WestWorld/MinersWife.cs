using Godot;
using GameAI.Concepts.FSM;

namespace GameAI.Concepts.FSM.WestWorld;

public partial class MinersWife : BaseGameEntity
{
    public string Location { get; set; } = WestWorld.Location.Shack;
    public bool Cooking { get; set; } = false;

    public override void _Ready()
    {
        base._Ready();
        StateMachine.SetGlobalState(new WifesGlobalState());
        StateMachine.SetCurrentState(new DoHouseWork());
    }
}

// States

public class WifesGlobalState : State<MinersWife>
{
    public override void Enter(MinersWife entity) { }
    public override void Exit(MinersWife entity) { }
    
    public override void Execute(MinersWife entity)
    {
        if (GD.Randf() < 0.1)
        {
            entity.StateMachine.ChangeState(new VisitBathroom());
        }
    }

    public override bool OnMessage(MinersWife entity, Telegram telegram)
    {
        if (telegram.Msg == MessageTypes.HiHoneyImHome)
        {
            GD.Print($"{entity.Name}: Hi honey. Let me make you some of mah fine stew");
            entity.StateMachine.ChangeState(new CookStew());
            return true;
        }
        return false;
    }
}

public class DoHouseWork : State<MinersWife>
{
    public override void Enter(MinersWife entity)
    {
        GD.Print($"{entity.Name}: Time to do some more housework!");
    }

    public override void Execute(MinersWife entity)
    {
        switch (GD.Randi() % 3)
        {
            case 0: GD.Print($"{entity.Name}: Moppin' the floor"); break;
            case 1: GD.Print($"{entity.Name}: Washin' the dishes"); break;
            case 2: GD.Print($"{entity.Name}: Makin' the bed"); break;
        }
    }

    public override void Exit(MinersWife entity) { }
    public override bool OnMessage(MinersWife entity, Telegram telegram) { return false; }
}

public class VisitBathroom : State<MinersWife>
{
    public override void Enter(MinersWife entity)
    {
        GD.Print($"{entity.Name}: Walkin' to the can. Need to powda mah nose");
    }

    public override void Execute(MinersWife entity)
    {
        GD.Print($"{entity.Name}: Ahhhhhh! Sweet relief!");
        entity.StateMachine.RevertToPreviousState();
    }

    public override void Exit(MinersWife entity)
    {
        GD.Print($"{entity.Name}: Leavin' the Jon");
    }

    public override bool OnMessage(MinersWife entity, Telegram telegram) { return false; }
}

public class CookStew : State<MinersWife>
{
    public override void Enter(MinersWife entity)
    {
        if (!entity.Cooking)
        {
            GD.Print($"{entity.Name}: Putting the stew in the oven");
            MessageDispatcher.Instance.DispatchMessage(1.5, entity, entity, MessageTypes.StewReady);
            entity.Cooking = true;
        }
    }

    public override void Execute(MinersWife entity)
    {
        GD.Print($"{entity.Name}: Fussin' over food");
    }

    public override void Exit(MinersWife entity)
    {
        GD.Print($"{entity.Name}: Puttin' the stew on the table");
    }

    public override bool OnMessage(MinersWife entity, Telegram telegram)
    {
        if (telegram.Msg == MessageTypes.StewReady)
        {
            GD.Print($"{entity.Name}: StewReady! Lets eat");
            
            // Find miner
            var miner = entity.GetParent().FindChild("Miner", true, false) as BaseGameEntity;
            if (miner != null)
            {
                MessageDispatcher.Instance.DispatchMessage(0, entity, miner, MessageTypes.StewReady);
            }

            entity.Cooking = false;
            entity.StateMachine.ChangeState(new DoHouseWork());
            return true;
        }
        return false;
    }
}
