using Godot;
using System.Collections.Generic;

namespace GameAI.Concepts.Steering;

public class SteeringPath
{
    public List<Vector2> Waypoints { get; set; } = new List<Vector2>();
    public int CurrentWaypointIndex { get; set; } = 0;
    public bool Loop { get; set; } = false;

    public SteeringPath() { }
    
    public SteeringPath(List<Vector2> points, bool loop = false)
    {
        Waypoints = points;
        Loop = loop;
    }

    public Vector2 GetCurrentWaypoint()
    {
        if (Waypoints.Count == 0) return Vector2.Zero;
        return Waypoints[CurrentWaypointIndex];
    }

    public bool IsFinished()
    {
        return !Loop && CurrentWaypointIndex >= Waypoints.Count - 1;
    }

    public void SetNextWaypoint()
    {
        if (Waypoints.Count == 0) return;

        if (Loop)
        {
            CurrentWaypointIndex = (CurrentWaypointIndex + 1) % Waypoints.Count;
        }
        else
        {
            if (CurrentWaypointIndex < Waypoints.Count - 1)
            {
                CurrentWaypointIndex++;
            }
        }
    }
}
