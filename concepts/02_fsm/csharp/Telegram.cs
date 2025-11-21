using Godot;
using System.Collections.Generic;

namespace GameAI.Concepts.FSM;

public struct Telegram
{
    public GodotObject Sender;
    public GodotObject Receiver;
    public string Msg;
    public double DispatchTime;
    public Godot.Collections.Dictionary ExtraInfo;

    public Telegram(GodotObject sender, GodotObject receiver, string msg, double time, Godot.Collections.Dictionary info = null)
    {
        Sender = sender;
        Receiver = receiver;
        Msg = msg;
        DispatchTime = time;
        ExtraInfo = info;
    }
}
