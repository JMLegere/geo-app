using System.Collections.Generic;
using UnityEngine;
using GeoApp.Domain;
using GeoApp.Utilities;

namespace GeoApp.Controllers
{
    public class WaypointController : MonoBehaviour
    {
        public TextAsset dataFile;

        private readonly List<Waypoint> _waypoints = new();

        void Start()
        {
            if (dataFile != null)
            {
                var list = JsonUtility.FromJson<WaypointList>(dataFile.text);
                _waypoints.AddRange(list.waypoints);
            }
        }

        void Update()
        {
            foreach (var waypoint in _waypoints)
            {
                if (waypoint.discovered) continue;

                double distance = GeoUtils.Haversine(LocationController.CurrentLocation, waypoint.Position);
                if (distance < 20d)
                {
                    waypoint.discovered = true;
                    Debug.Log($"Waypoint {waypoint.id} discovered!");
                }
            }
        }

        [System.Serializable]
        private class WaypointList
        {
            public List<Waypoint> waypoints;
        }
    }
}
