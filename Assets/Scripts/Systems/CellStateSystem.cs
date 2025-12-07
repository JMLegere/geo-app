using System;
using System.Collections.Generic;
using GeoApp.Map;

namespace GeoApp.Systems
{
    /// <summary>
    /// Applies state transitions for cells based on player location.
    /// </summary>
    public class CellStateSystem
    {
        public event Action<CellData> OnCellStateChanged;

        public IReadOnlyDictionary<int, CellData> Cells => _cells;
        public int? CurrentCellId => _currentCellId;

        private readonly Dictionary<int, CellData> _cells = new Dictionary<int, CellData>();
        private readonly GeoReference _geo;
        private int? _currentCellId;

        public CellStateSystem(IEnumerable<CellData> cells, GeoReference geoReference, HashSet<int> explored, HashSet<int> revealed)
        {
            _geo = geoReference;
            foreach (var cell in cells)
            {
                if (explored.Contains(cell.Id))
                {
                    cell.State = CellState.Explored;
                }
                else if (revealed.Contains(cell.Id))
                {
                    cell.State = CellState.Revealed;
                }

                _cells[cell.Id] = cell;
            }
        }

        public bool TryGetCell(int id, out CellData cell)
        {
            return _cells.TryGetValue(id, out cell);
        }

        public CellData FindContainingCell(UnityEngine.Vector2 latLon, UnityEngine.Vector2? offsetMeters = null)
        {
            UnityEngine.Vector2 point;
            if (offsetMeters.HasValue)
            {
                point = offsetMeters.Value;
            }
            else
            {
                point = GeoUtils.LatLonToMeters(latLon) - _geo.OriginMeters;
            }
            foreach (var kvp in _cells)
            {
                var cell = kvp.Value;
                if (cell.PolygonMeters == null || cell.PolygonMeters.Length == 0)
                {
                    continue;
                }

                if (GeoUtils.PointInPolygon(point, cell.PolygonMeters))
                {
                    return cell;
                }
            }

            return null;
        }

        public void UpdatePlayerLocation(UnityEngine.Vector2 latLon, UnityEngine.Vector2? offsetMeters = null)
        {
            var nextCell = FindContainingCell(latLon, offsetMeters);
            if (nextCell == null)
            {
                return;
            }

            if (_currentCellId.HasValue && _currentCellId.Value != nextCell.Id)
            {
                if (_cells.TryGetValue(_currentCellId.Value, out var prev))
                {
                    if (prev.State == CellState.Present)
                    {
                        SetState(prev, CellState.Explored);
                    }
                }
            }

            _currentCellId = nextCell.Id;
            SetState(nextCell, CellState.Present);
            nextCell.LastVisitedUnixSeconds = GeoUtils.UnixTimeSeconds();
        }

        public void RevealCell(int id)
        {
            if (_cells.TryGetValue(id, out var cell))
            {
                if (cell.State == CellState.Unexplored)
                {
                    SetState(cell, CellState.Revealed);
                }
            }
        }

        public void ClearPresence()
        {
            if (_currentCellId.HasValue && _cells.TryGetValue(_currentCellId.Value, out var prev))
            {
                if (prev.State == CellState.Present)
                {
                    SetState(prev, CellState.Explored);
                }
            }

            _currentCellId = null;
        }

        private void SetState(CellData cell, CellState state)
        {
            if (cell.State == state)
            {
                return;
            }

            cell.State = state;
            OnCellStateChanged?.Invoke(cell);
        }
    }
}
