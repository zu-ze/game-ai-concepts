using Godot;
using System.Collections.Generic;

namespace GameAI.Concepts.Soccer;

public class SupportSpotCalculator
{
    public SoccerTeam Team { get; private set; }
    public Vector2 BestSupportingSpot { get; private set; } = Vector2.Zero;
    public float BestSupportingSpotScore { get; private set; } = 0.0f;

    // Config
    public float SpotCanPassScore { get; set; } = 2.0f;
    public float SpotCanScoreFromPositionScore { get; set; } = 1.0f;
    public float OptimalDistance { get; set; } = 200.0f;

    private List<Vector2> _spots = new List<Vector2>();

    public SupportSpotCalculator(SoccerTeam team)
    {
        Team = team;
        GenerateSpots();
    }

    private void GenerateSpots()
    {
        int cols = 12;
        int rows = 7;
        float stepX = Team.Pitch.PitchWidth / cols;
        float stepY = Team.Pitch.PitchHeight / rows;

        for (int y = 1; y < rows; y++)
        {
            for (int x = 1; x < cols; x++)
            {
                _spots.Add(new Vector2(x * stepX, y * stepY));
            }
        }
    }

    public Vector2 DetermineBestSupportingSpot()
    {
        BestSupportingSpot = Vector2.Zero;
        BestSupportingSpotScore = -1.0f;

        var controlling = Team.ControllingPlayer;
        if (controlling == null) return Vector2.Zero;

        foreach (var spot in _spots)
        {
            float score = CalculateScore(spot, controlling);
            if (score > BestSupportingSpotScore)
            {
                BestSupportingSpotScore = score;
                BestSupportingSpot = spot;
            }
        }

        return BestSupportingSpot;
    }

    private float CalculateScore(Vector2 spot, PlayerBase controllingPlayer)
    {
        float score = 0.0f;

        // 1. Passing Potential
        if (IsSafeToPass(controllingPlayer.GlobalPosition, spot))
        {
            score += SpotCanPassScore;
        }
        else
        {
            return 0.0f;
        }

        // 2. Goal Shot Potential
        if (CanScore(spot))
        {
            score += SpotCanScoreFromPositionScore;
        }

        // 3. Optimal Distance
        float dist = controllingPlayer.GlobalPosition.DistanceTo(spot);
        float distDiff = Mathf.Abs(dist - OptimalDistance);
        if (distDiff < OptimalDistance)
        {
            score += (OptimalDistance - distDiff) / OptimalDistance;
        }

        // 4. Bonus: Upfield
        bool isUpfield = false;
        if (Team.Color == SoccerTeam.TeamColor.Red)
        {
            // Attacking Right
            isUpfield = spot.X > controllingPlayer.GlobalPosition.X;
        }
        else
        {
            // Attacking Left
            isUpfield = spot.X < controllingPlayer.GlobalPosition.X;
        }

        if (isUpfield) score += 1.0f;

        return score;
    }

    private bool IsSafeToPass(Vector2 from, Vector2 to)
    {
        Vector2 rayDir = (to - from).Normalized();
        float rayLen = from.DistanceTo(to);
        var opponents = (Team.Color == SoccerTeam.TeamColor.Red) ? Team.Pitch.BlueTeam.Players : Team.Pitch.RedTeam.Players;

        foreach (var opp in opponents)
        {
            Vector2 toOpp = opp.GlobalPosition - from;
            float projection = toOpp.Dot(rayDir);

            if (projection > 0 && projection < rayLen)
            {
                float perpDist = (toOpp - rayDir * projection).Length();
                if (perpDist < 40.0f) return false;
            }
        }
        return true;
    }

    private bool CanScore(Vector2 from)
    {
        return IsSafeToPass(from, Team.OpponentsGoal.Center);
    }
}
