using System.Collections;
using UnityEngine;
using UnityEngine.Android;
using GeoApp.Domain;

namespace GeoApp.Controllers
{
    public class LocationController : MonoBehaviour
    {
        public static Vector2d CurrentLocation { get; private set; }

        IEnumerator Start()
        {
            if (!Input.location.isEnabledByUser)
                yield break;

            Input.location.Start(10f, 10f);

            while (Input.location.status == LocationServiceStatus.Initializing)
                yield return new WaitForSeconds(1);

            if (Input.location.status == LocationServiceStatus.Running)
            {
                InvokeRepeating(nameof(UpdateLocation), 0f, 1f);
            }
        }

        void UpdateLocation()
        {
            var data = Input.location.lastData;
            CurrentLocation = new Vector2d(data.latitude, data.longitude);
        }
    }
}
