using UnityEngine;
using GeoApp.Domain;

namespace GeoApp.Infrastructure
{
    public class InputLocationService : ILocationService
    {
        public bool IsEnabledByUser => Input.location.isEnabledByUser;
        public LocationStatus Status => (LocationStatus)(int)Input.location.status;
        public void Start(double desiredAccuracyInMeters, double updateDistanceInMeters)
        {
            Input.location.Start((float)desiredAccuracyInMeters, (float)updateDistanceInMeters);
        }
        public (double latitude, double longitude) LastData => (Input.location.lastData.latitude, Input.location.lastData.longitude);
    }
}
