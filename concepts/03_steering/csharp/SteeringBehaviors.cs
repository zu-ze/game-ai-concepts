using Godot;
using System;
using System.Collections.Generic;

namespace GameAI.Concepts.Steering;

public class SteeringBehaviors
{
    [Flags]
    public enum BehaviorType
    {
        None = 0,
        Seek = 1 << 0,
        Flee = 1 << 1,
        Arrive = 1 << 2,
        Wander = 1 << 3,
        Cohesion = 1 << 4,
        Separation = 1 << 5,
        Alignment = 1 << 6,
        ObstacleAvoidance = 1 << 7,
        WallAvoidance = 1 << 8,
        FollowPath = 1 << 9,
        Pursuit = 1 << 10,
        Evade = 1 << 11,
        Interpose = 1 << 12,
        Hide = 1 << 13,
        OffsetPursuit = 1 << 14,
    }

    private Vehicle _vehicle;
    public BehaviorType Flags { get; set; }

    public Vehicle TargetAgent1 { get; set; }
    public Vehicle TargetAgent2 { get; set; }
    public Vector2 TargetPos { get; set; }
    public SteeringPath Path { get; set; }
    
    // Weights
    public float WeightSeek { get; set; } = 1.0f;
    public float WeightFlee { get; set; } = 1.0f;
    public float WeightArrive { get; set; } = 1.0f;
    public float WeightWander { get; set; } = 1.0f;
    public float WeightSeparation { get; set; } = 5.0f;
    public float WeightAlignment { get; set; } = 1.0f;
    public float WeightCohesion { get; set; } = 2.0f;
    public float WeightPursuit { get; set; } = 1.0f;
    public float WeightEvade { get; set; } = 1.0f;
    public float WeightObstacleAvoidance { get; set; } = 10.0f;
    public float WeightWallAvoidance { get; set; } = 10.0f;
    public float WeightFollowPath { get; set; } = 1.0f;
    public float WeightHide { get; set; } = 1.0f;
    public float WeightInterpose { get; set; } = 1.0f;
    public float WeightOffsetPursuit { get; set; } = 1.0f;

    // Wander
    private float _wanderRadius = 30.0f;
    private float _wanderDistance = 50.0f;
    private float _wanderJitter = 40.0f;
    private Vector2 _wanderTarget;
    
    // Avoidance
    public float DetectionLength { get; set; } = 100.0f;
    public List<Vehicle> Neighbors { get; set; } = new List<Vehicle>();
    public List<BaseGameEntity> Obstacles { get; set; } = new List<BaseGameEntity>();
    public List<Wall> Walls { get; set; } = new List<Wall>();
    public float WaypointSeekDistSq { get; set; } = 20.0f * 20.0f;
    public Vector2 Offset { get; set; }

    public SteeringBehaviors(Vehicle vehicle)
    {
        _vehicle = vehicle;
        float theta = (float)GD.RandRange(0, Mathf.Tau);
        _wanderTarget = new Vector2(Mathf.Cos(theta), Mathf.Sin(theta)) * _wanderRadius;
    }

    public Vector2 Calculate(float delta)
    {
        Vector2 force = Vector2.Zero;
        
        if (On(BehaviorType.ObstacleAvoidance)) force += ObstacleAvoidance(Obstacles) * WeightObstacleAvoidance;
        if (On(BehaviorType.WallAvoidance)) force += WallAvoidance(Walls) * WeightWallAvoidance;

        if (On(BehaviorType.Seek)) force += Seek(TargetPos) * WeightSeek;
        if (On(BehaviorType.Flee)) force += Flee(TargetPos) * WeightFlee;
        if (On(BehaviorType.Arrive)) force += Arrive(TargetPos, 2) * WeightArrive;
        if (On(BehaviorType.Wander)) force += Wander(delta) * WeightWander;
        
        if (On(BehaviorType.Pursuit) && TargetAgent1 != null) 
            force += Pursuit(TargetAgent1) * WeightPursuit;
            
        if (On(BehaviorType.Evade) && TargetAgent1 != null) 
            force += Evade(TargetAgent1) * WeightEvade;
            
        if (On(BehaviorType.Interpose) && TargetAgent1 != null && TargetAgent2 != null)
            force += Interpose(TargetAgent1, TargetAgent2) * WeightInterpose;
            
        if (On(BehaviorType.Hide) && TargetAgent1 != null)
            force += Hide(TargetAgent1, Obstacles) * WeightHide;
            
        if (On(BehaviorType.FollowPath) && Path != null)
            force += FollowPath() * WeightFollowPath;
            
        if (On(BehaviorType.OffsetPursuit) && TargetAgent1 != null)
            force += OffsetPursuit(TargetAgent1, Offset) * WeightOffsetPursuit;

        if (On(BehaviorType.Separation)) force += Separation(Neighbors) * WeightSeparation;
        if (On(BehaviorType.Alignment)) force += Alignment(Neighbors) * WeightAlignment;
        if (On(BehaviorType.Cohesion)) force += Cohesion(Neighbors) * WeightCohesion;

        if (force.Length() > _vehicle.MaxForce)
        {
            force = force.Normalized() * _vehicle.MaxForce;
        }

        return force;
    }

    private bool On(BehaviorType bt)
    {
        return (Flags & bt) == bt;
    }

    // Helper methods
    public void SeekOn() { Flags |= BehaviorType.Seek; }
    public void FleeOn() { Flags |= BehaviorType.Flee; }
    public void ArriveOn() { Flags |= BehaviorType.Arrive; }
    public void WanderOn() { Flags |= BehaviorType.Wander; }
    public void PursuitOn() { Flags |= BehaviorType.Pursuit; }
    public void EvadeOn() { Flags |= BehaviorType.Evade; }
    public void SeparationOn() { Flags |= BehaviorType.Separation; }
    public void AlignmentOn() { Flags |= BehaviorType.Alignment; }
    public void CohesionOn() { Flags |= BehaviorType.Cohesion; }
    public void ObstacleAvoidanceOn() { Flags |= BehaviorType.ObstacleAvoidance; }
    public void WallAvoidanceOn() { Flags |= BehaviorType.WallAvoidance; }
    public void FollowPathOn() { Flags |= BehaviorType.FollowPath; }
    public void InterposeOn() { Flags |= BehaviorType.Interpose; }
    public void HideOn() { Flags |= BehaviorType.Hide; }
    public void OffsetPursuitOn() { Flags |= BehaviorType.OffsetPursuit; }

    public void SeekOff() { Flags &= ~BehaviorType.Seek; }
    public void FleeOff() { Flags &= ~BehaviorType.Flee; }
    public void ArriveOff() { Flags &= ~BehaviorType.Arrive; }
    public void WanderOff() { Flags &= ~BehaviorType.Wander; }
    public void PursuitOff() { Flags &= ~BehaviorType.Pursuit; }
    public void EvadeOff() { Flags &= ~BehaviorType.Evade; }
    public void SeparationOff() { Flags &= ~BehaviorType.Separation; }
    public void AlignmentOff() { Flags &= ~BehaviorType.Alignment; }
    public void CohesionOff() { Flags &= ~BehaviorType.Cohesion; }
    public void ObstacleAvoidanceOff() { Flags &= ~BehaviorType.ObstacleAvoidance; }
    public void WallAvoidanceOff() { Flags &= ~BehaviorType.WallAvoidance; }
    public void FollowPathOff() { Flags &= ~BehaviorType.FollowPath; }
    public void InterposeOff() { Flags &= ~BehaviorType.Interpose; }
    public void HideOff() { Flags &= ~BehaviorType.Hide; }
    public void OffsetPursuitOff() { Flags &= ~BehaviorType.OffsetPursuit; }

    public void AllOff() { Flags = 0; }

    private Vector2 Seek(Vector2 target)
    {
        Vector2 desiredVelocity = (target - _vehicle.GlobalPosition).Normalized() * _vehicle.MaxSpeed;
        return desiredVelocity - _vehicle.Velocity;
    }

    private Vector2 Flee(Vector2 target)
    {
        float panicDistanceSq = 100.0f * 100.0f;
        if (_vehicle.GlobalPosition.DistanceSquaredTo(target) > panicDistanceSq)
        {
            return Vector2.Zero;
        }
        Vector2 desiredVelocity = (_vehicle.GlobalPosition - target).Normalized() * _vehicle.MaxSpeed;
        return desiredVelocity - _vehicle.Velocity;
    }

    private Vector2 Arrive(Vector2 target, int deceleration)
    {
        Vector2 toTarget = target - _vehicle.GlobalPosition;
        float dist = toTarget.Length();

        if (dist > 0)
        {
            float speed = dist / ((float)deceleration * 0.3f);
            speed = Mathf.Min(speed, _vehicle.MaxSpeed);
            
            Vector2 desiredVelocity = toTarget * (speed / dist);
            return desiredVelocity - _vehicle.Velocity;
        }
        return Vector2.Zero;
    }

    private Vector2 Wander(float delta)
    {
        float jitter = _wanderJitter * delta;
        _wanderTarget += new Vector2((float)GD.RandRange(-1, 1), (float)GD.RandRange(-1, 1)) * jitter;
        _wanderTarget = _wanderTarget.Normalized() * _wanderRadius;

        Vector2 targetLocal = _wanderTarget + new Vector2(_wanderDistance, 0);
        Vector2 targetWorld = _vehicle.GlobalPosition + targetLocal.Rotated(_vehicle.Rotation);

        return targetWorld - _vehicle.GlobalPosition;
    }

    private Vector2 Pursuit(Vehicle evader)
    {
        Vector2 toEvader = evader.GlobalPosition - _vehicle.GlobalPosition;
        float relativeHeading = _vehicle.Heading.Dot(evader.Heading);

        if (toEvader.Dot(_vehicle.Heading) > 0 && relativeHeading < -0.95f)
        {
            return Seek(evader.GlobalPosition);
        }

        float lookAheadTime = toEvader.Length() / (_vehicle.MaxSpeed + evader.Velocity.Length());
        return Seek(evader.GlobalPosition + evader.Velocity * lookAheadTime);
    }

    private Vector2 Evade(Vehicle pursuer)
    {
        Vector2 toPursuer = pursuer.GlobalPosition - _vehicle.GlobalPosition;
        float lookAheadTime = toPursuer.Length() / (_vehicle.MaxSpeed + pursuer.Velocity.Length());
        return Flee(pursuer.GlobalPosition + pursuer.Velocity * lookAheadTime);
    }
    
    private Vector2 ObstacleAvoidance(List<BaseGameEntity> obstacles)
    {
        float boxLength = DetectionLength + (_vehicle.Velocity.Length() / _vehicle.MaxSpeed) * DetectionLength;
        
        BaseGameEntity closestIntersectingObstacle = null;
        float distToClosestIp = float.MaxValue;
        Vector2 localPosOfClosestObstacle = Vector2.Zero;
        
        Transform2D vehicleTransform = _vehicle.GlobalTransform;
        Transform2D inverseTransform = vehicleTransform.AffineInverse();
        
        foreach (var obs in obstacles)
        {
            Vector2 localPos = inverseTransform * obs.GlobalPosition;
            
            if (localPos.X >= 0 && localPos.X < boxLength + obs.BoundingRadius)
            {
                float expandedRadius = obs.BoundingRadius + _vehicle.BoundingRadius;
                
                if (Mathf.Abs(localPos.Y) < expandedRadius)
                {
                    float cX = localPos.X;
                    float cY = localPos.Y;
                    
                    float sqrtPart = Mathf.Sqrt(expandedRadius * expandedRadius - cY * cY);
                    float ip = cX - sqrtPart;
                    
                    if (ip <= 0) ip = cX + sqrtPart;
                    
                    if (ip < distToClosestIp)
                    {
                        distToClosestIp = ip;
                        closestIntersectingObstacle = obs;
                        localPosOfClosestObstacle = localPos;
                    }
                }
            }
        }
        
        Vector2 steeringForce = Vector2.Zero;
        
        if (closestIntersectingObstacle != null)
        {
            float multiplier = 1.0f + (boxLength - localPosOfClosestObstacle.X) / boxLength;
            steeringForce.Y = (closestIntersectingObstacle.BoundingRadius - localPosOfClosestObstacle.Y) * multiplier;
            
            float brakingWeight = 0.2f;
            steeringForce.X = (closestIntersectingObstacle.BoundingRadius - localPosOfClosestObstacle.X) * brakingWeight;
            
            return steeringForce.Rotated(_vehicle.Rotation);
        }
        
        return Vector2.Zero;
    }

    private Vector2 WallAvoidance(List<Wall> walls)
    {
        Vector2[] feelers = CreateFeelers();
        Vector2 steeringForce = Vector2.Zero;
        float distToClosestIp = float.MaxValue;
        Wall closestWall = null;
        Vector2 closestPoint = Vector2.Zero;
        
        foreach (var feeler in feelers)
        {
            foreach (var wall in walls)
            {
                var intersection = Geometry2D.SegmentIntersectsSegment(_vehicle.GlobalPosition, feeler, wall.From, wall.To);
                if (intersection.HasValue) // Variant to Vector2 conversion usually explicit but Variant can be null checked? Wait. In C#, returns Variant.
                {
                     // C# API for SegmentIntersectsSegment returns Variant. 
                     // Need to check type or null
                     if (intersection.Value.VariantType == Variant.Type.Vector2)
                     {
                         Vector2 ip = intersection.Value.AsVector2();
                         float dist = _vehicle.GlobalPosition.DistanceTo(ip);
                         if (dist < distToClosestIp)
                         {
                             distToClosestIp = dist;
                             closestWall = wall;
                             closestPoint = ip;
                         }
                     }
                }
            }
            
            if (closestWall != null)
            {
                Vector2 overshoot = feeler - closestPoint;
                steeringForce = closestWall.Normal * overshoot.Length();
            }
        }
        
        return steeringForce;
    }
    
    private Vector2[] CreateFeelers()
    {
        Vector2[] feelers = new Vector2[3];
        float feelerLength = DetectionLength;
        
        feelers[0] = _vehicle.GlobalPosition + _vehicle.Heading * feelerLength;
        
        Vector2 left = _vehicle.Heading.Rotated(Mathf.DegToRad(-45.0f)) * (feelerLength * 0.5f);
        Vector2 right = _vehicle.Heading.Rotated(Mathf.DegToRad(45.0f)) * (feelerLength * 0.5f);
        
        feelers[1] = _vehicle.GlobalPosition + left;
        feelers[2] = _vehicle.GlobalPosition + right;
        
        return feelers;
    }

    private Vector2 Interpose(Vehicle agentA, Vehicle agentB)
    {
        Vector2 midPoint = (agentA.GlobalPosition + agentB.GlobalPosition) / 2.0f;
        float timeToMid = _vehicle.GlobalPosition.DistanceTo(midPoint) / _vehicle.MaxSpeed;
        
        Vector2 aFuture = agentA.GlobalPosition + agentA.Velocity * timeToMid;
        Vector2 bFuture = agentB.GlobalPosition + agentB.Velocity * timeToMid;
        
        midPoint = (aFuture + bFuture) / 2.0f;
        
        return Arrive(midPoint, 0);
    }

    private Vector2 Hide(Vehicle hunter, List<BaseGameEntity> obstacles)
    {
        float distToClosest = float.MaxValue;
        Vector2 bestHidingSpot = Vector2.Zero;
        bool foundSpot = false;
        
        foreach (var obs in obstacles)
        {
            Vector2 hidingSpot = GetHidingPosition(obs.GlobalPosition, obs.BoundingRadius, hunter.GlobalPosition);
            float dist = hidingSpot.DistanceSquaredTo(_vehicle.GlobalPosition);
            
            if (dist < distToClosest)
            {
                distToClosest = dist;
                bestHidingSpot = hidingSpot;
                foundSpot = true;
            }
        }
        
        if (foundSpot)
        {
            return Arrive(bestHidingSpot, 0);
        }
        
        return Evade(hunter);
    }

    private Vector2 GetHidingPosition(Vector2 obsPos, float radius, Vector2 hunterPos)
    {
        float distFromBoundary = 30.0f;
        float distAway = radius + distFromBoundary;
        Vector2 toObs = (obsPos - hunterPos).Normalized();
        return obsPos + toObs * distAway;
    }

    private Vector2 FollowPath()
    {
        if (Path.IsFinished())
        {
            return Arrive(Path.GetCurrentWaypoint(), 2);
        }
        
        Vector2 target = Path.GetCurrentWaypoint();
        if (_vehicle.GlobalPosition.DistanceSquaredTo(target) < WaypointSeekDistSq)
        {
            Path.SetNextWaypoint();
        }
        
        if (!Path.IsFinished())
        {
            return Seek(Path.GetCurrentWaypoint());
        }
        else
        {
            return Arrive(Path.GetCurrentWaypoint(), 2);
        }
    }

    private Vector2 OffsetPursuit(Vehicle leader, Vector2 offset)
    {
        Vector2 worldOffset = offset.Rotated(leader.Rotation);
        Vector2 worldTarget = leader.GlobalPosition + worldOffset;
        
        Vector2 toOffset = worldTarget - _vehicle.GlobalPosition;
        float lookAheadTime = toOffset.Length() / (_vehicle.MaxSpeed + leader.Velocity.Length());
        
        return Arrive(worldTarget + leader.Velocity * lookAheadTime, 0);
    }
    
    // Group Behaviors

    private Vector2 Separation(List<Vehicle> neighbors)
    {
        Vector2 force = Vector2.Zero;
        foreach (var neighbor in neighbors)
        {
            if (neighbor != _vehicle)
            {
                Vector2 toAgent = _vehicle.GlobalPosition - neighbor.GlobalPosition;
                float dist = toAgent.Length();
                if (dist < 50.0f) // Separation radius
                {
                    force += toAgent.Normalized() / dist;
                }
            }
        }
        return force;
    }

    private Vector2 Alignment(List<Vehicle> neighbors)
    {
        Vector2 avgHeading = Vector2.Zero;
        int count = 0;
        foreach (var neighbor in neighbors)
        {
            if (neighbor != _vehicle && _vehicle.GlobalPosition.DistanceSquaredTo(neighbor.GlobalPosition) < 10000)
            {
                avgHeading += neighbor.Heading;
                count++;
            }
        }

        if (count > 0)
        {
            avgHeading /= count;
            avgHeading -= _vehicle.Heading;
        }
        return avgHeading;
    }

    private Vector2 Cohesion(List<Vehicle> neighbors)
    {
        Vector2 centerMass = Vector2.Zero;
        int count = 0;
        foreach (var neighbor in neighbors)
        {
            if (neighbor != _vehicle && _vehicle.GlobalPosition.DistanceSquaredTo(neighbor.GlobalPosition) < 10000)
            {
                centerMass += neighbor.GlobalPosition;
                count++;
            }
        }

        if (count > 0)
        {
            centerMass /= count;
            return Seek(centerMass);
        }
        return Vector2.Zero;
    }
}
