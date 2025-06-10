using System.Collections;
using UnityEngine;
using UnityEngine.Android;
using GeoApp.Domain;
using GeoApp.Infrastructure;

namespace GeoApp.Controllers
{
    public class LocationController : MonoBehaviour
    {
        public static Vector2d CurrentLocation { get; private set; }

        LocationServiceRunner _runner;

        IEnumerator Start()
        {
            _runner = new LocationServiceRunner(new InputLocationService());
            yield return _runner.Initialize(() => InvokeRepeating(nameof(UpdateLocation), 0f, 1f));
        }

        void UpdateLocation()
        {
            var (lat, lon) = _runner.GetLastLocation();
            CurrentLocation = new Vector2d(lat, lon);
        }
    }
}
