using UnityEngine;

namespace GeoApp.Map
{
    /// <summary>
    /// Maps lat/lon to Unity world space using a configurable mercator origin.
    /// </summary>
    public class GeoReference : MonoBehaviour
    {
        [Header("Reference")]
        [Tooltip("Mercator origin in lat (x) / lon (y) degrees.")]
        [SerializeField] private Vector2 originLatLon = new Vector2(37.7749f, -122.4194f);

        [Tooltip("Meters represented by one Unity unit.")]
        [SerializeField] private float metersPerUnityUnit = 1.0f;

        [Tooltip("Optional world origin override.")]
        [SerializeField] private Vector3 worldOrigin = Vector3.zero;

        private Vector2 _originMeters;

        public Vector2 OriginLatLon => originLatLon;
        public Vector2 OriginMeters => _originMeters;
        public float MetersPerUnityUnit => Mathf.Max(0.001f, metersPerUnityUnit);

        public void SetOrigin(Vector2 latLon)
        {
            originLatLon = latLon;
            _originMeters = GeoUtils.LatLonToMeters(originLatLon);
        }

        public void SetMetersPerUnit(float metersPerUnit)
        {
            metersPerUnityUnit = Mathf.Max(0.001f, metersPerUnit);
        }

        public Vector3 LatLonToWorld(Vector2 latLon)
        {
            var meters = GeoUtils.LatLonToMeters(latLon);
            var delta = meters - _originMeters;
            var scale = 1.0f / MetersPerUnityUnit;
            return worldOrigin + new Vector3(delta.x * scale, 0f, delta.y * scale);
        }

        public Vector2 WorldToLatLon(Vector3 worldPos)
        {
            var scale = MetersPerUnityUnit;
            var meters = _originMeters + new Vector2((worldPos.x - worldOrigin.x) * scale, (worldPos.z - worldOrigin.z) * scale);
            return GeoUtils.MetersToLatLon(meters);
        }

        private void Awake()
        {
            _originMeters = GeoUtils.LatLonToMeters(originLatLon);
        }
    }
}
