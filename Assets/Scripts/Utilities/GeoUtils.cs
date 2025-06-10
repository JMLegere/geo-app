using GeoApp.Domain;

namespace GeoApp.Utilities
{
    public static class GeoUtils
    {
        const double EarthRadius = 6371000; // meters

        public static double Haversine(Vector2d a, Vector2d b)
        {
            double dLat = DegreesToRadians(b.x - a.x);
            double dLon = DegreesToRadians(b.y - a.y);

            double lat1 = DegreesToRadians(a.x);
            double lat2 = DegreesToRadians(b.x);

            double sinDLat = System.Math.Sin(dLat / 2);
            double sinDLon = System.Math.Sin(dLon / 2);

            double aa = sinDLat * sinDLat + System.Math.Cos(lat1) * System.Math.Cos(lat2) * sinDLon * sinDLon;
            double c = 2 * System.Math.Atan2(System.Math.Sqrt(aa), System.Math.Sqrt(1 - aa));

            return EarthRadius * c;
        }

        static double DegreesToRadians(double deg) => deg * System.Math.PI / 180d;
    }
}
