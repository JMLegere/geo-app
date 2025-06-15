using System.Collections.Generic;
using UnityEngine;
using GeoApp.Domain;

namespace GeoApp.Infrastructure
{
    public class SharpVoronoiService
    {
        // Placeholder for actual Voronoi generation using SharpVoronoiLib
        public List<VoronoiCell> GenerateVoronoi(Vector2d[] sites, Rect bounds) =>
            // Implementation would call into SharpVoronoiLib and convert results
            new();
    }
}
