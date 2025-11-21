using Godot;

namespace GameAI.Concepts.FSM;

public abstract class State<T> where T : Node
{
    public abstract void Enter(T entity);
    public abstract void Execute(T entity);
    public abstract void Exit(T entity);
    public abstract bool OnMessage(T entity, Telegram telegram);
}
