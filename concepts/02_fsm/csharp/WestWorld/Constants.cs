using Godot;

namespace GameAI.Concepts.FSM.WestWorld;

public static class Location
{
    public const string Shack = "Shack";
    public const string GoldMine = "GoldMine";
    public const string Bank = "Bank";
    public const string Saloon = "Saloon";
}

public static class MessageTypes
{
    public const string HiHoneyImHome = "HiHoneyImHome";
    public const string StewReady = "StewReady";
    public const string GoHome = "GoHome";
    public const string ReceiveBall = "ReceiveBall";
    public const string PassToMe = "PassToMe";
    public const string SupportAttacker = "SupportAttacker";
    public const string Wait = "Wait";
}
