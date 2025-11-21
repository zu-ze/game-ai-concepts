using Godot;
using GameAI.Concepts.FSM;

namespace GameAI.Concepts.FSM.WestWorld;

public partial class Miner : BaseGameEntity
{
    public string Location { get; set; } = WestWorld.Location.Shack;
    public int GoldCarried { get; set; } = 0;
    public int MoneyInBank { get; set; } = 0;
    public int Thirst { get; set; } = 0;
    public int Fatigue { get; set; } = 0;

    public BaseGameEntity Wife { get; set; }

    public const int ComfortLevel = 5;
    public const int MaxNuggets = 3;
    public const int ThirstLevel = 5;
    public const int TirednessThreshold = 5;

    public override void _Ready()
    {
        base._Ready();
        StateMachine.SetCurrentState(new GoHomeAndSleepTilRested());
    }

    public void UpdateStats() => Thirst++;
    public void AddGold(int amount) => GoldCarried += amount;
    public void DepositGold()
    {
        MoneyInBank += GoldCarried;
        GoldCarried = 0;
    }
    public void BuyAndDrinkWhiskey()
    {
        Thirst = 0;
        MoneyInBank -= 2;
    }

    public bool IsPocketsFull() => GoldCarried >= MaxNuggets;
    public bool IsThirsty() => Thirst >= ThirstLevel;
    public bool IsFatigued() => Fatigue > TirednessThreshold;
}

// States

public class EnterMineAndDigForGold : State<Miner>
{
    public override void Enter(Miner entity)
    {
        if (entity.Location != WestWorld.Location.GoldMine)
        {
            GD.Print($"{entity.Name}: Walkin' to the goldmine");
            entity.Location = WestWorld.Location.GoldMine;
        }
    }

    public override void Execute(Miner entity)
    {
        entity.AddGold(1);
        entity.Fatigue++;
        entity.UpdateStats();
        GD.Print($"{entity.Name}: Pickin' up a nugget");

        if (entity.IsPocketsFull())
        {
            entity.StateMachine.ChangeState(new VisitBankAndDepositGold());
        }
        else if (entity.IsThirsty())
        {
            entity.StateMachine.ChangeState(new QuenchThirst());
        }
    }

    public override void Exit(Miner entity)
    {
        GD.Print($"{entity.Name}: Ah'm leavin' the goldmine with mah pockets full o' sweet gold");
    }

    public override bool OnMessage(Miner entity, Telegram telegram) { return false; }
}

public class VisitBankAndDepositGold : State<Miner>
{
    public override void Enter(Miner entity)
    {
        if (entity.Location != WestWorld.Location.Bank)
        {
            GD.Print($"{entity.Name}: Goin' to the bank. Yes siree");
            entity.Location = WestWorld.Location.Bank;
        }
    }

    public override void Execute(Miner entity)
    {
        entity.DepositGold();
        GD.Print($"{entity.Name}: Depositing gold. Total savings now: {entity.MoneyInBank}");

        if (entity.MoneyInBank >= 5)
        {
            GD.Print($"{entity.Name}: WooHoo! Rich enough for now. Back home to mah li'l lady");
            entity.StateMachine.ChangeState(new GoHomeAndSleepTilRested());
        }
        else if (entity.IsThirsty())
        {
            entity.StateMachine.ChangeState(new QuenchThirst());
        }
        else
        {
            entity.StateMachine.ChangeState(new EnterMineAndDigForGold());
        }
    }

    public override void Exit(Miner entity)
    {
        GD.Print($"{entity.Name}: Leavin' the bank");
    }

    public override bool OnMessage(Miner entity, Telegram telegram) { return false; }
}

public class GoHomeAndSleepTilRested : State<Miner>
{
    public override void Enter(Miner entity)
    {
        if (entity.Location != WestWorld.Location.Shack)
        {
            GD.Print($"{entity.Name}: Walkin' home");
            entity.Location = WestWorld.Location.Shack;

            if (entity.Wife != null)
            {
                MessageDispatcher.Instance.DispatchMessage(0, entity, entity.Wife, MessageTypes.HiHoneyImHome);
            }
        }
    }

    public override void Execute(Miner entity)
    {
        if (entity.Fatigue < 0)
        {
            GD.Print($"{entity.Name}: All mah fatigue has drained away. Time to find more gold!");
            entity.StateMachine.ChangeState(new EnterMineAndDigForGold());
        }
        else
        {
            entity.Fatigue--;
            GD.Print($"{entity.Name}: ZZZZ...");
        }
    }

    public override void Exit(Miner entity)
    {
        GD.Print($"{entity.Name}: Leaving the house");
    }

    public override bool OnMessage(Miner entity, Telegram telegram)
    {
        if (telegram.Msg == MessageTypes.StewReady)
        {
            GD.Print($"{entity.Name}: Okay Hun, ahm a comin'!");
            entity.StateMachine.ChangeState(new EatStew());
            return true;
        }
        return false;
    }
}

public class QuenchThirst : State<Miner>
{
    public override void Enter(Miner entity)
    {
        if (entity.Location != WestWorld.Location.Saloon)
        {
            GD.Print($"{entity.Name}: Boy, ah sure is thusty! Walking to the saloon");
            entity.Location = WestWorld.Location.Saloon;
        }
    }

    public override void Execute(Miner entity)
    {
        if (entity.MoneyInBank >= 2)
        {
            entity.BuyAndDrinkWhiskey();
            GD.Print($"{entity.Name}: That's mighty fine sippin liquer");
            entity.StateMachine.ChangeState(new EnterMineAndDigForGold());
        }
        else
        {
            GD.Print($"{entity.Name}: Error! Not enough money!");
            entity.StateMachine.ChangeState(new GoHomeAndSleepTilRested());
        }
    }

    public override void Exit(Miner entity)
    {
        GD.Print($"{entity.Name}: Leaving the saloon, feelin' good");
    }

    public override bool OnMessage(Miner entity, Telegram telegram) { return false; }
}

public class EatStew : State<Miner>
{
    public override void Enter(Miner entity)
    {
        GD.Print($"{entity.Name}: Smells Reaaal goood Elsa!");
    }

    public override void Execute(Miner entity)
    {
        GD.Print($"{entity.Name}: Tastes real good too!");
        entity.StateMachine.RevertToPreviousState();
    }

    public override void Exit(Miner entity)
    {
        GD.Print($"{entity.Name}: Thankya li'l lady.");
    }

    public override bool OnMessage(Miner entity, Telegram telegram) { return false; }
}
