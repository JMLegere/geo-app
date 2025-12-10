using System;
using System.Collections.Generic;
using UnityEngine;

namespace GeoApp.Map
{
    /// <summary>
    /// Immutable data for a single Voronoi cell plus a mutable state field.
    /// </summary>
    [Serializable]
    public class CellData
    {
        public int Id;
        public Vector2 SeedLatLon;
        public Vector2[] PolygonLatLon;
        public Vector2[] PolygonMeters;
        public List<int> NeighborIds = new List<int>();
        public CellState State = CellState.Unexplored;
        public double LastVisitedUnixSeconds;

        public CellData Clone()
        {
            return new CellData
            {
                Id = Id,
                SeedLatLon = SeedLatLon,
                PolygonLatLon = (Vector2[])PolygonLatLon.Clone(),
                PolygonMeters = (Vector2[])PolygonMeters.Clone(),
                NeighborIds = new List<int>(NeighborIds),
                State = State,
                LastVisitedUnixSeconds = LastVisitedUnixSeconds
            };
        }
    }
}
