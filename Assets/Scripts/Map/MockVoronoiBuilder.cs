using System.Collections.Generic;
using UnityEngine;

namespace GeoApp.Map
{
    /// <summary>
    /// Lightweight mock grid generator to simulate Voronoi cells for MVP/testing.
    /// Generates square-ish cells around an origin spaced at ~200 m.
    /// </summary>
    public static class MockVoronoiBuilder
    {
        public static List<CellData> BuildGrid(Vector2 originLatLon, float spacingMeters = 200f, int radius = 2)
        {
            var cells = new List<CellData>();
            var half = spacingMeters * 0.5f;
            int id = 0;

            for (int x = -radius; x <= radius; x++)
            {
                for (int y = -radius; y <= radius; y++)
                {
                    var centerMeters = new Vector2(x * spacingMeters, y * spacingMeters);
                    var polygonMeters = new[]
                    {
                        centerMeters + new Vector2(-half, -half),
                        centerMeters + new Vector2(-half, half),
                        centerMeters + new Vector2(half, half),
                        centerMeters + new Vector2(half, -half)
                    };

                    var polygonLatLon = new Vector2[polygonMeters.Length];
                    for (int i = 0; i < polygonMeters.Length; i++)
                    {
                        polygonLatLon[i] = GeoUtils.OffsetLatLon(originLatLon, polygonMeters[i]);
                    }

                    cells.Add(new CellData
                    {
                        Id = id++,
                        SeedLatLon = GeoUtils.OffsetLatLon(originLatLon, centerMeters),
                        PolygonLatLon = polygonLatLon,
                        PolygonMeters = (Vector2[])polygonMeters.Clone()
                    });
                }
            }

            return cells;
        }
    }
}
