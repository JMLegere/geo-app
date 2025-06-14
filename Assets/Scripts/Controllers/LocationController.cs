using System.Collections;
using GeoApp.Domain;
using UnityEngine;
using UnityEngine.Android;

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
            yield return new WaitUntil(() => Input.location.status != LocationServiceStatus.Initializing);

            if (Input.location.status == LocationServiceStatus.Running)
                InvokeRepeating(nameof(UpdateLocation), 0f, 1f);
        }

        void UpdateLocation() =>
            CurrentLocation = new Vector2d(Input.location.lastData.latitude, Input.location.lastData.longitude);
    }
}
