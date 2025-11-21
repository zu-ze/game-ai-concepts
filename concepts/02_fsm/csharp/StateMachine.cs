using Godot;

namespace GameAI.Concepts.FSM;

public class StateMachine<T> where T : Node
{
    private T _owner;
    public State<T> CurrentState { get; private set; }
    public State<T> PreviousState { get; private set; }
    public State<T> GlobalState { get; set; }

    public StateMachine(T owner)
    {
        _owner = owner;
    }

    public void SetCurrentState(State<T> s) { CurrentState = s; }
    public void SetPreviousState(State<T> s) { PreviousState = s; }
    public void SetGlobalState(State<T> s) { GlobalState = s; }

    public void Update()
    {
        if (GlobalState != null) GlobalState.Execute(_owner);
        if (CurrentState != null) CurrentState.Execute(_owner);
    }

    public void ChangeState(State<T> newState)
    {
        if (newState == null)
        {
            GD.PushError("StateMachine: trying to change to null state");
            return;
        }

        PreviousState = CurrentState;
        if (CurrentState != null)
        {
            CurrentState.Exit(_owner);
        }
        
        CurrentState = newState;
        CurrentState.Enter(_owner);
    }

    public void RevertToPreviousState()
    {
        if (PreviousState != null)
        {
            ChangeState(PreviousState);
        }
    }

    public bool HandleMessage(Telegram telegram)
    {
        if (CurrentState != null && CurrentState.OnMessage(_owner, telegram)) return true;
        if (GlobalState != null && GlobalState.OnMessage(_owner, telegram)) return true;
        return false;
    }
}
