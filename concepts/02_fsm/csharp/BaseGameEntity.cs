using Godot;
using System;
using System.Collections.Generic;

namespace GameAI.Concepts.FSM;

public abstract partial class BaseGameEntity : CharacterBody2D
{
    private static int _nextValidId = 0;
    public int ID { get; private set; }
    public float BoundingRadius { get; set; } = 10.0f;
    
    public StateMachine<BaseGameEntity> StateMachine { get; set; }

    public BaseGameEntity()
    {
        ID = _nextValidId++;
    }

    public override void _Ready()
    {
        StateMachine = new StateMachine<BaseGameEntity>(this);
    }

    public override void _PhysicsProcess(double delta)
    {
        StateMachine.Update();
    }

    public virtual bool HandleMessage(Telegram telegram)
    {
        return StateMachine.HandleMessage(telegram);
    }
}
