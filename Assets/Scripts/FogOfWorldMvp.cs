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
    [SerializeField] private Color mapBaseColor = new Color(0.7f, 0.75f, 0.8f, 1f);

    [Header("MapTiler")]
    [SerializeField] private bool enableMapTiler = true;
    [SerializeField] private string mapTilerApiKey = "ntk9pZ3tCDGGdrzs9ajs";
    [SerializeField] private MapTilerStaticLoader mapTilerLoader;

    [Header("Debug")]
    [SerializeField] private bool logRenderDetails = true;
    [SerializeField] private bool suppressLocationDebugLogs = true;
    [SerializeField] private bool forceStartOverride = true;
    [SerializeField] private Vector2 forcedStartLatLon = new Vector2(45.9636f, -66.6431f);
    [SerializeField] private bool forceZoomOverride = true;
    [SerializeField, Range(1, 22)] private int forcedZoom = 14;
    [SerializeField] private bool forcedAutoCalculateZoom = false;
    [SerializeField] private string forcedStyleId = "streets-v2";

    private const string LegacyDefaultApiKey = "YA13yb8j8V4OehBzdMhC";
    private const string CurrentDefaultApiKey = "ntk9pZ3tCDGGdrzs9ajs";

    private GeoReference _geoReference;
    private PlayerLocationTracker _locationTracker;
    private CellStateSystem _stateSystem;
    private CellOverlayController _overlayController;
    private GameObject _playerMarkerInstance;
    private GameObject _mapBackgroundInstance;
    private MapBackground _mapBackground;
    private float _gridSpanMeters;

    private void Awake()
    {
        EnsureGeoReference();
        EnsureOverlayRoot();
        EnsureLocationTracker();
        EnsureMapTilerLoader();
        ApplyRuntimeOverrides();
    }

    private void OnValidate()
    {
        // Upgrade any serialized legacy key to the current default so the old masked key stops being used.
        if (mapTilerApiKey == LegacyDefaultApiKey)
        {
            mapTilerApiKey = CurrentDefaultApiKey;
        }
    }

    private void Start()
    {
        StartCoroutine(BootstrapRoutine());
    }

    private IEnumerator BootstrapRoutine()
    {
        // Wait for first location fix or simulation start.
        yield return new WaitUntil(() => _locationTracker.HasLocation);

        _geoReference.SetOrigin(_locationTracker.CurrentLatLon);
        _geoReference.SetMetersPerUnit(metersPerUnityUnit);

        // Build mock cells around the starting point.
        var cells = MockVoronoiBuilder.BuildGrid(_geoReference.OriginLatLon, cellSpacingMeters, gridRadius);

        // Background map placeholder sized to the grid.
        BuildBackground();
        TryLoadBasemap();
        LogRenderDetails("background ready");

        // Load persisted states.
        var (explored, revealed) = CellPersistence.Load();
        _stateSystem = new CellStateSystem(cells, _geoReference, explored, revealed);

        // Build visuals.
        _overlayController = overlayRoot.gameObject.AddComponent<CellOverlayController>();
        _overlayController.BuildCells(cells, _geoReference, _stateSystem);

        // Player marker.
        _playerMarkerInstance = playerMarkerPrefab != null
            ? Instantiate(playerMarkerPrefab, overlayRoot)
            : GameObject.CreatePrimitive(PrimitiveType.Sphere);
        _playerMarkerInstance.name = "PlayerMarker";
        _playerMarkerInstance.transform.SetParent(overlayRoot, false);
        _playerMarkerInstance.transform.localScale = Vector3.one * 10f;

        _locationTracker.OnLocationUpdated += HandleLocationUpdate;
        _stateSystem.UpdatePlayerLocation(_locationTracker.CurrentLatLon);
        HandleLocationUpdate(_locationTracker.CurrentLatLon);
    }

    private void HandleLocationUpdate(Vector2 latLon)
    {
        var offset = _locationTracker.CurrentOffsetMeters;
        _stateSystem.UpdatePlayerLocation(latLon, offset);
        var worldPos = new Vector3(offset.x / _geoReference.MetersPerUnityUnit, 0f, offset.y / _geoReference.MetersPerUnityUnit);
        _overlayController.UpdatePlayerMarker(_playerMarkerInstance, worldPos);
        PersistProgress();
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

        if (suppressLocationDebugLogs)
        {
            _locationTracker.SetDebugLogging(false);
        }

        if (forceStartOverride)
        {
            _locationTracker.ForceSimulatedStart(forcedStartLatLon);
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
        _mapBackground = bg;
        _gridSpanMeters = span;

        if (mapTilerLoader != null)
        {
            mapTilerLoader.mapBackground = bg;
        }
    }

    private void EnsureMapTilerLoader()
    {
        if (!enableMapTiler)
        {
            return;
        }

        if (mapTilerLoader == null)
        {
            mapTilerLoader = GetComponent<MapTilerStaticLoader>();
            if (mapTilerLoader == null)
            {
                mapTilerLoader = gameObject.AddComponent<MapTilerStaticLoader>();
            }
        }

        if (!string.IsNullOrEmpty(mapTilerApiKey))
        {
            mapTilerLoader.SetApiKey(mapTilerApiKey);
        }

        mapTilerLoader.SetGeoReference(_geoReference);
        mapTilerLoader.OnTextureApplied += HandleMapTextureApplied;
        if (forceZoomOverride)
        {
            mapTilerLoader.ForceZoomAndStyle(forcedZoom, forcedAutoCalculateZoom, forcedStyleId);
        }
    }

    private void TryLoadBasemap()
    {
        if (!enableMapTiler || mapTilerLoader == null || _mapBackground == null)
        {
            return;
        }

        var span = Mathf.Max(1f, _gridSpanMeters);
        mapTilerLoader.mapBackground = _mapBackground;
        mapTilerLoader.SetGeoReference(_geoReference);
        if (!string.IsNullOrEmpty(mapTilerApiKey))
        {
            mapTilerLoader.SetApiKey(mapTilerApiKey);
        }

        mapTilerLoader.LoadForArea(_geoReference.OriginLatLon, span, span);
        LogRenderDetails("requested basemap");
    }

    private void OnDestroy()
    {
        if (mapTilerLoader != null)
        {
            mapTilerLoader.OnTextureApplied -= HandleMapTextureApplied;
        }
    }

    private void ApplyRuntimeOverrides()
    {
        if (_geoReference != null && forceStartOverride)
        {
            _geoReference.SetOrigin(forcedStartLatLon);
        }

        if (mapTilerLoader != null && forceZoomOverride)
        {
            mapTilerLoader.ForceZoomAndStyle(forcedZoom, forcedAutoCalculateZoom, forcedStyleId);
        }
    }

    private void HandleMapTextureApplied(Texture2D texture)
    {
        LogRenderDetails(texture != null ? $"MapTiler texture '{texture.name}' applied" : "MapTiler returned null texture");
    }

    private void LogRenderDetails(string reason)
    {
        if (!logRenderDetails)
        {
            return;
        }

        var renderer = _mapBackgroundInstance != null ? _mapBackgroundInstance.GetComponent<MeshRenderer>() : null;
        var material = renderer != null ? renderer.sharedMaterial : null;
        var texture = material != null ? material.mainTexture : null;
        var color = material != null ? material.color : mapBaseColor;
        var colorHex = ColorUtility.ToHtmlStringRGBA(color);
        var gridInfo = _gridSpanMeters > 0f ? $"{_gridSpanMeters:0.#}m grid span" : "grid not built";
        var mapSource = texture != null ? $"texture '{texture.name}'" : $"flat color #{colorHex}";
        var mapTilerState = enableMapTiler && mapTilerLoader != null ? "MapTiler enabled" : "MapTiler disabled";
        var suffix = string.IsNullOrEmpty(reason) ? string.Empty : $" ({reason})";
        Debug.Log($"[FogOfWorldMvp] Under-fog render: {mapSource}, {gridInfo}, {mapTilerState}{suffix}.");
    }
}
