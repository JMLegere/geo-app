using GeoApp.Domain;
using static System.Math;

namespace GeoApp.Utilities
{
    public static class GeoUtils
    {
        const double EarthRadius = 6371000d; // meters
        const double Deg2Rad = PI / 180d;

        public static double Haversine(Vector2d a, Vector2d b)
        {
            double lat1 = a.x * Deg2Rad;
            double lat2 = b.x * Deg2Rad;

            double dLat = lat2 - lat1;
            double dLon = (b.y - a.y) * Deg2Rad;

            double sinLat = Sin(dLat * 0.5d);
            double sinLon = Sin(dLon * 0.5d);

            double h = sinLat * sinLat + Cos(lat1) * Cos(lat2) * sinLon * sinLon;
            return 2d * EarthRadius * Asin(Sqrt(h));
        }
    }
}
