using Godot;

namespace GameAI.Concepts.FSM;

public partial class MessageDispatcher : Node
{
    public static MessageDispatcher Instance { get; private set; }
    private List<Telegram> _priorityQueue = new List<Telegram>();

    public override void _Ready()
    {
        Instance = this;
    }

    public void DispatchMessage(double delay, GodotObject sender, GodotObject receiver, string msg, Godot.Collections.Dictionary extraInfo = null)
    {
        double currentTime = Time.GetTicksMsec() / 1000.0;
        
        if (delay <= 0.0)
        {
            Discharge(receiver, new Telegram(sender, receiver, msg, 0, extraInfo));
        }
        else
        {
            Telegram telegram = new Telegram(sender, receiver, msg, currentTime + delay, extraInfo);
            _priorityQueue.Add(telegram);
            _priorityQueue.Sort((a, b) => a.DispatchTime.CompareTo(b.DispatchTime));
        }
    }

    public void Discharge(GodotObject receiver, Telegram telegram)
    {
        if (GodotObject.IsInstanceValid(receiver))
        {
            if (receiver is BaseGameEntity entity)
            {
                entity.HandleMessage(telegram);
            }
        }
    }
    
    public override void _Process(double delta)
    {
        double currentTime = Time.GetTicksMsec() / 1000.0;
        
        while (_priorityQueue.Count > 0 && _priorityQueue[0].DispatchTime <= currentTime)
        {
            Telegram telegram = _priorityQueue[0];
            _priorityQueue.RemoveAt(0);
            Discharge(telegram.Receiver, telegram);
        }
    }
}
