using System.Collections;
using System.Collections.Generic;
using GeoApp.Map;
using GeoApp.Systems;
using GeoApp.View;
using UnityEngine;

/// <summary>
/// Minimal runtime bootstrap for the fog-of-world MVP using MapTiler for the basemap
/// and a mock Voronoi overlay.
/// </summary>
public class FogOfWorldMvp : MonoBehaviour
    {
    [Header("Cells")]
    [SerializeField] private float cellSpacingMeters = 200f;
    [SerializeField] private int gridRadius = 2;

    [Header("Rendering")]
    [SerializeField] private float metersPerUnityUnit = 1f;
    [SerializeField] private Transform overlayRoot;
    [SerializeField] private GameObject playerMarkerPrefab;
    [SerializeField] private bool debugLogging = true;
    [SerializeField] private Color mapBaseColor = new Color(0.7f, 0.75f, 0.8f, 1f);

    private GeoReference _geoReference;
    private PlayerLocationTracker _locationTracker;
    private CellStateSystem _stateSystem;
    private CellOverlayController _overlayController;
    private GameObject _playerMarkerInstance;
    private GameObject _mapBackgroundInstance;

    private void Awake()
    {
        EnsureGeoReference();
        EnsureOverlayRoot();
        EnsureLocationTracker();
        Log("Awake completed.");
    }

    private void Start()
    {
        StartCoroutine(BootstrapRoutine());
    }

    private IEnumerator BootstrapRoutine()
    {
        // Wait for first location fix or simulation start.
        yield return new WaitUntil(() => _locationTracker.HasLocation);
        Log("Location ready.");

        _geoReference.SetOrigin(_locationTracker.CurrentLatLon);
        _geoReference.SetMetersPerUnit(metersPerUnityUnit);

        // Build mock cells around the starting point.
        var cells = MockVoronoiBuilder.BuildGrid(_geoReference.OriginLatLon, cellSpacingMeters, gridRadius);
        Log($"Built mock grid with {cells.Count} cells.");

        // Background map placeholder sized to the grid.
        BuildBackground();

        // Load persisted states.
        var (explored, revealed) = CellPersistence.Load();
        _stateSystem = new CellStateSystem(cells, _geoReference, explored, revealed);

        // Build visuals.
        _overlayController = overlayRoot.gameObject.AddComponent<CellOverlayController>();
        _overlayController.BuildCells(cells, _geoReference, _stateSystem);
        Log("Overlay built.");

        // Player marker.
        _playerMarkerInstance = playerMarkerPrefab != null
            ? Instantiate(playerMarkerPrefab, overlayRoot)
            : GameObject.CreatePrimitive(PrimitiveType.Sphere);
        _playerMarkerInstance.name = "PlayerMarker";
        _playerMarkerInstance.transform.SetParent(overlayRoot, false);
        _playerMarkerInstance.transform.localScale = Vector3.one * 10f;
        Log("Player marker created.");

        _locationTracker.OnLocationUpdated += HandleLocationUpdate;
        _stateSystem.UpdatePlayerLocation(_locationTracker.CurrentLatLon);
        HandleLocationUpdate(_locationTracker.CurrentLatLon);
        Log("Bootstrap complete.");
    }

    private void HandleLocationUpdate(Vector2 latLon)
    {
        var offset = _locationTracker.CurrentOffsetMeters;
        _stateSystem.UpdatePlayerLocation(latLon, offset);
        var worldPos = new Vector3(offset.x / _geoReference.MetersPerUnityUnit, 0f, offset.y / _geoReference.MetersPerUnityUnit);
        _overlayController.UpdatePlayerMarker(_playerMarkerInstance, worldPos);
        PersistProgress();
        Log($"HandleLocationUpdate -> world {worldPos}");
    }

    private void PersistProgress()
    {
        var explored = new System.Collections.Generic.HashSet<int>();
        var revealed = new System.Collections.Generic.HashSet<int>();
        foreach (var kvp in _stateSystem.Cells)
        {
            var cell = kvp.Value;
            if (cell.State == CellState.Explored || cell.State == CellState.Present)
            {
                explored.Add(cell.Id);
            }
            else if (cell.State == CellState.Revealed)
            {
                revealed.Add(cell.Id);
            }
        }
        CellPersistence.Save(explored, revealed);
    }

    private void EnsureGeoReference()
    {
        _geoReference = GetComponent<GeoReference>();
        if (_geoReference == null)
        {
            _geoReference = gameObject.AddComponent<GeoReference>();
        }
    }

    private void EnsureOverlayRoot()
    {
        if (overlayRoot == null)
        {
            var go = new GameObject("CellOverlayRoot");
            go.transform.SetParent(transform, false);
            overlayRoot = go.transform;
        }
    }

    private void EnsureLocationTracker()
    {
        _locationTracker = GetComponent<PlayerLocationTracker>();
        if (_locationTracker == null)
        {
            _locationTracker = gameObject.AddComponent<PlayerLocationTracker>();
        }
    }

    private void BuildBackground()
    {
        if (_mapBackgroundInstance != null)
        {
            return;
        }

        var span = (gridRadius * 2 + 1) * cellSpacingMeters;
        _mapBackgroundInstance = new GameObject("MapBackground");
        _mapBackgroundInstance.transform.SetParent(transform, false);
        _mapBackgroundInstance.transform.position = new Vector3(0f, -0.05f, 0f); // slight offset to avoid z-fighting
        var bg = _mapBackgroundInstance.AddComponent<MapBackground>();
        var renderer = _mapBackgroundInstance.GetComponent<MeshRenderer>();
        bg.Initialize(span, span, metersPerUnityUnit);
        renderer.sharedMaterial.color = mapBaseColor;
    }

    private void Log(string message)
    {
        if (!debugLogging)
        {
            return;
        }

        Debug.Log($"[FogOfWorldMvp] {message}");
    }
}
