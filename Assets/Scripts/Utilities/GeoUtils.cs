using GeoApp.Domain;
using static System.Math;

namespace GeoApp.Utilities
{
    public static class GeoUtils
    {
        const double EarthRadius = 6371000; // meters
        const double Deg2Rad = PI / 180d;

        public static double Haversine(Vector2d a, Vector2d b)
        {
            var dLat = (b.x - a.x) * Deg2Rad;
            var dLon = (b.y - a.y) * Deg2Rad;

            var lat1 = a.x * Deg2Rad;
            var lat2 = b.x * Deg2Rad;

            var sinDLat = Sin(dLat * 0.5);
            var sinDLon = Sin(dLon * 0.5);

            var aa = sinDLat * sinDLat + Cos(lat1) * Cos(lat2) * sinDLon * sinDLon;
            var c = 2 * Atan2(Sqrt(aa), Sqrt(1 - aa));
            return EarthRadius * c;
        }
    }
}
