using Godot;
using System;

namespace GameAI.Concepts.Soccer;

public class Region
{
    public enum RegionModifier { HalfSize, Normal }

    public int ID { get; set; }
    public float Top { get; set; }
    public float Left { get; set; }
    public float Right { get; set; }
    public float Bottom { get; set; }
    public float Width { get; set; }
    public float Height { get; set; }
    public Vector2 Center { get; set; }

    public Region(float left, float top, float right, float bottom, int id = -1)
    {
        Left = left;
        Top = top;
        Right = right;
        Bottom = bottom;
        ID = id;

        Width = Mathf.Abs(right - left);
        Height = Mathf.Abs(bottom - top);
        Center = new Vector2((left + right) * 0.5f, (top + bottom) * 0.5f);
    }

    public bool Inside(Vector2 pos, RegionModifier modifier = RegionModifier.Normal)
    {
        if (modifier == RegionModifier.Normal)
        {
            return pos.X > Left && pos.X < Right && pos.Y > Top && pos.Y < Bottom;
        }
        else
        {
            float marginX = Width * 0.25f;
            float marginY = Height * 0.25f;
            return pos.X > (Left + marginX) && pos.X < (Right - marginX) && pos.Y > (Top + marginY) && pos.Y < (Bottom - marginY);
        }
    }

    public Vector2 GetRandomPosition()
    {
        return new Vector2((float)GD.RandRange(Left, Right), (float)GD.RandRange(Top, Bottom));
    }
}
