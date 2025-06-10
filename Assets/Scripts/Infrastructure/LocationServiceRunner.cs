using System.Collections;
using GeoApp.Domain;

namespace GeoApp.Infrastructure
{
    public class LocationServiceRunner
    {
        readonly ILocationService _service;

        public LocationServiceRunner(ILocationService service)
        {
            _service = service;
        }

        public IEnumerator Initialize(System.Action onRunning)
        {
            if (!_service.IsEnabledByUser)
                yield break;

            _service.Start(10f, 10f);

            while (_service.Status == LocationStatus.Initializing)
                yield return null;

            if (_service.Status == LocationStatus.Running)
                onRunning?.Invoke();
        }

        public (double latitude, double longitude) GetLastLocation() => _service.LastData;
    }
}
