using Godot;
using System;
using System.Collections.Generic;

namespace GameAI.Concepts.Steering;

public class CellSpacePartition
{
    private List<Vehicle>[] _cells;
    private float _spaceWidth;
    private float _spaceHeight;
    private int _numCellsX;
    private int _numCellsY;
    private float _cellSizeX;
    private float _cellSizeY;

    public CellSpacePartition(float width, float height, int cellsX, int cellsY)
    {
        _spaceWidth = width;
        _spaceHeight = height;
        _numCellsX = cellsX;
        _numCellsY = cellsY;
        _cellSizeX = width / cellsX;
        _cellSizeY = height / cellsY;

        _cells = new List<Vehicle>[_numCellsX * _numCellsY];
        for (int i = 0; i < _cells.Length; i++)
        {
            _cells[i] = new List<Vehicle>();
        }
    }

    public void AddEntity(Vehicle entity)
    {
        int idx = PositionToIndex(entity.GlobalPosition);
        _cells[idx].Add(entity);
    }

    public void UpdateEntity(Vehicle entity, Vector2 oldPos)
    {
        int oldIdx = PositionToIndex(oldPos);
        int newIdx = PositionToIndex(entity.GlobalPosition);

        if (oldIdx == newIdx) return;

        _cells[oldIdx].Remove(entity);
        _cells[newIdx].Add(entity);
    }

    public List<Vehicle> CalculateNeighbors(Vector2 targetPos, float queryRadius)
    {
        List<Vehicle> neighbors = new List<Vehicle>();
        Rect2 queryBox = new Rect2(targetPos.X - queryRadius, targetPos.Y - queryRadius, queryRadius * 2, queryRadius * 2);

        int startX = (int)Mathf.Floor(queryBox.Position.X / _cellSizeX);
        int endX = (int)Mathf.Floor(queryBox.End.X / _cellSizeX);
        int startY = (int)Mathf.Floor(queryBox.Position.Y / _cellSizeY);
        int endY = (int)Mathf.Floor(queryBox.End.Y / _cellSizeY);

        startX = Mathf.Clamp(startX, 0, _numCellsX - 1);
        endX = Mathf.Clamp(endX, 0, _numCellsX - 1);
        startY = Mathf.Clamp(startY, 0, _numCellsY - 1);
        endY = Mathf.Clamp(endY, 0, _numCellsY - 1);

        for (int y = startY; y <= endY; y++)
        {
            for (int x = startX; x <= endX; x++)
            {
                int idx = y * _numCellsX + x;
                foreach (var entity in _cells[idx])
                {
                    if (entity.GlobalPosition.DistanceSquaredTo(targetPos) < queryRadius * queryRadius)
                    {
                        neighbors.Add(entity);
                    }
                }
            }
        }

        return neighbors;
    }

    private int PositionToIndex(Vector2 pos)
    {
        int idxX = (int)Mathf.Clamp(pos.X / _cellSizeX, 0, _numCellsX - 1);
        int idxY = (int)Mathf.Clamp(pos.Y / _cellSizeY, 0, _numCellsY - 1);
        return idxY * _numCellsX + idxX;
    }
    
    public void EmptyCells()
    {
        foreach (var cell in _cells)
        {
            cell.Clear();
        }
    }
}
