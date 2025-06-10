using UnityEngine;
using GeoApp.Controllers;
using GeoApp.Infrastructure;

namespace GeoApp.Core
{
    public class GameManager : MonoBehaviour
    {
        [SerializeField] LocationController locationController;
        [SerializeField] WaypointController waypointController;
        [SerializeField] FogRenderer fogRenderer;

        void Start()
        {
            // In a real build this would generate Voronoi cells based on location
            Debug.Log("GameManager started");
        }
    }
}
