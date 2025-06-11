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
            double dLat = (b.x - a.x) * Deg2Rad;
            double dLon = (b.y - a.y) * Deg2Rad;

            double sinLat = Sin(dLat / 2d);
            double sinLon = Sin(dLon / 2d);

            double lat1 = a.x * Deg2Rad;
            double lat2 = b.x * Deg2Rad;

            double h = sinLat * sinLat + Cos(lat1) * Cos(lat2) * sinLon * sinLon;
            double c = 2d * Asin(Sqrt(h));
            return EarthRadius * c;
        }
    }
}
