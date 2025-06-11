using GeoApp.Domain;
using static System.Math;

namespace GeoApp.Utilities
{
    public static class GeoUtils
    {
        const double EarthRadius = 6371000; // meters

        public static double Haversine(Vector2d a, Vector2d b)
        {
            var dLat = ToRadians(b.x - a.x);
            var dLon = ToRadians(b.y - a.y);

            var lat1 = ToRadians(a.x);
            var lat2 = ToRadians(b.x);

            var sinDLat = Sin(dLat / 2);
            var sinDLon = Sin(dLon / 2);

            var aa = sinDLat * sinDLat + Cos(lat1) * Cos(lat2) * sinDLon * sinDLon;
            var c = 2 * Atan2(Sqrt(aa), Sqrt(1 - aa));
            return EarthRadius * c;
        }

        static double ToRadians(double degrees) => degrees * PI / 180d;
    }
}
