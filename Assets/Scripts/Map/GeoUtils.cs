using System;
using UnityEngine;

namespace GeoApp.Map
{
    /// <summary>
    /// Helper geo math (mercator projection, point-in-polygon).
    /// </summary>
    public static class GeoUtils
    {
        private const double EarthRadiusMeters = 6378137.0; // WGS84

        public static Vector2 LatLonToMeters(Vector2 latLon)
        {
            var lat = Mathf.Clamp(latLon.x, -85.05112878f, 85.05112878f) * Mathf.Deg2Rad;
            var lon = latLon.y * Mathf.Deg2Rad;
            var x = EarthRadiusMeters * lon;
            var y = EarthRadiusMeters * Math.Log(Math.Tan(Math.PI / 4.0 + lat / 2.0));
            return new Vector2((float)x, (float)y);
        }

        public static Vector2 MetersToLatLon(Vector2 meters)
        {
            var lon = meters.x / EarthRadiusMeters;
            var lat = 2.0 * Math.Atan(Math.Exp(meters.y / EarthRadiusMeters)) - Math.PI / 2.0;
            return new Vector2((float)(lat * Mathf.Rad2Deg), (float)(lon * Mathf.Rad2Deg));
        }

        public static Vector2 OffsetLatLon(Vector2 originLatLon, Vector2 offsetMeters)
        {
            var originMeters = LatLonToMeters(originLatLon);
            var targetMeters = originMeters + offsetMeters;
            return MetersToLatLon(targetMeters);
        }

        public static bool PointInPolygon(Vector2 point, Vector2[] polygon)
        {
            // Ray casting algorithm (assumes polygon is non-self-intersecting)
            var inside = false;
            for (int i = 0, j = polygon.Length - 1; i < polygon.Length; j = i++)
            {
                var pi = polygon[i];
                var pj = polygon[j];
                var intersect = ((pi.y > point.y) != (pj.y > point.y)) &&
                                (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y + 1e-6f) + pi.x);
                if (intersect)
                {
                    inside = !inside;
                }
            }
            return inside;
        }

        public static double UnixTimeSeconds()
        {
            return (DateTime.UtcNow - DateTime.UnixEpoch).TotalSeconds;
        }
    }
}
