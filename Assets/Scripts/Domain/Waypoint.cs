using GeoApp.Domain;

namespace GeoApp.Domain
{
    [System.Serializable]
    public class Waypoint
    {
        public string id;
        public double latitude;
        public double longitude;
        public bool discovered;

        public Vector2d Position => new Vector2d(latitude, longitude);
    }
}
