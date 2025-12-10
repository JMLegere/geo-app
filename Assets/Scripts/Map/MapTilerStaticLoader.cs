using System;
using System.Collections;
using System.Globalization;
using System.Text;
using UnityEngine;
using UnityEngine.Networking;

namespace GeoApp.Map
{
    /// <summary>
    /// Fetches a static map image from MapTiler and applies it to the MapBackground.
    /// This is a lightweight placeholder until a full tile-based map is integrated.
    /// </summary>
    public class MapTilerStaticLoader : MonoBehaviour
    {
        [Header("MapTiler")]
        [SerializeField] private string apiKey = "";
        [SerializeField] private string apiKeyEnvVar = "MAPTILER_API_KEY";
        [SerializeField] private string styleId = "streets-v2";
        [SerializeField, Range(1, 22)] private int zoom = 14;
        [SerializeField] private bool autoCalculateZoom = false;
        [SerializeField, Range(1, 22)] private int minZoom = 1;
        [SerializeField, Range(1, 22)] private int maxZoom = 20;
        [SerializeField] private int imageWidth = 1024;
        [SerializeField] private int imageHeight = 1024;

        [Header("Anchoring")]
        [SerializeField] private bool useGeoReferenceOrigin = true;
        [SerializeField] private Vector2 manualCenterLatLon = new Vector2(37.7749f, -122.4194f);
        [SerializeField] private float fallbackAreaMeters = 2000f;

        [Header("References")]
        [SerializeField] public MapBackground mapBackground;
        [SerializeField] private GeoReference geoReference;

        [Header("Retry")]
        [SerializeField] private float backgroundWaitSeconds = 0.25f;
        [SerializeField] private int backgroundMaxAttempts = 40;

        [Header("Debug")]
        [SerializeField] private bool autoLoadOnStart = true;
        [SerializeField] private bool debugLogging = true;
        [SerializeField] private bool logErrorBody = true;
        [SerializeField] private bool preferEnvApiKey = true;

        [Header("Free Tier")]
        [SerializeField] private bool useStaticSnapshots = false; // static snapshots require paid tier; free by default uses tile snapshot
        [SerializeField] private bool fallbackToTileOnStaticError = true;
        [SerializeField] private bool fallbackToBasicStyleOnTileError = true;

        [Header("Forced Overrides")]
        [SerializeField] private bool forceZoomSettings = true;
        [SerializeField, Range(1, 22)] private int forcedZoom = 14;
        [SerializeField] private bool forcedAutoCalculateZoom = false;
        [SerializeField] private string forcedStyleId = "streets-v2";

        public event Action<Texture2D> OnTextureApplied;

        private Coroutine _loadRoutine;
        private const double EarthCircumferenceMeters = 40075016.68557849;
        private const int TileSize = 256; // use 256px tiles to match MapTiler free-tier raster endpoint
        private const int KeyRevealCount = 4;
        private bool _apiKeyFromEnv;
        private bool _staticForbidden;
        private bool _tileStyleFallbackUsed;

        private struct MapRequest
        {
            public Vector2 Center;
            public float WidthMeters;
            public float HeightMeters;
            public int? ZoomOverride;
        }

        private void Awake()
        {
            ApplyForcedZoomSettings();
            if (mapBackground == null)
            {
                mapBackground = GetComponentInChildren<MapBackground>();
            }

            if (geoReference == null)
            {
                geoReference = GetComponent<GeoReference>();
            }

            EnsureApiKey();
        }

        private void Start()
        {
            if (string.IsNullOrEmpty(apiKey))
            {
                Debug.LogWarning("[MapTilerStaticLoader] API key not set. Please provide a MapTiler API key or set the MAPTILER_API_KEY environment variable.");
                return;
            }

            if (!autoLoadOnStart)
            {
                Log("Auto-load disabled; waiting for explicit LoadForArea call.");
                return;
            }

            var center = useGeoReferenceOrigin && geoReference != null ? geoReference.OriginLatLon : manualCenterLatLon;
            var widthMeters = mapBackground != null ? mapBackground.WidthMeters : fallbackAreaMeters;
            var heightMeters = mapBackground != null ? mapBackground.HeightMeters : fallbackAreaMeters;
            Log($"Starting MapTiler fetch at lat {center.x}, lon {center.y}, zoom {zoom}, style {styleId}. {DescribeApiKey()}");
            var request = new MapRequest
            {
                Center = center,
                WidthMeters = widthMeters,
                HeightMeters = heightMeters,
                ZoomOverride = autoCalculateZoom ? (int?)null : zoom
            };
            _loadRoutine = StartCoroutine(LoadWhenReady(request));
        }

        /// <summary>
        /// Request a static map covering a specific world span, typically matching the fog grid.
        /// </summary>
        public void LoadForArea(Vector2 centerLatLon, float widthMeters, float heightMeters, int? zoomOverride = null)
        {
            EnsureApiKey();
            if (string.IsNullOrEmpty(apiKey))
            {
                Debug.LogWarning("[MapTilerStaticLoader] API key not set. Please provide a MapTiler API key or set the MAPTILER_API_KEY environment variable.");
                return;
            }

            if (_loadRoutine != null)
            {
                Log("Stopping previous MapTiler load routine before starting a new request.");
                StopCoroutine(_loadRoutine);
            }

            var request = new MapRequest
            {
                Center = centerLatLon,
                WidthMeters = Mathf.Max(1f, widthMeters),
                HeightMeters = Mathf.Max(1f, heightMeters),
                ZoomOverride = zoomOverride
            };
            Log($"LoadForArea called -> center {centerLatLon.x},{centerLatLon.y}, width {request.WidthMeters}, height {request.HeightMeters}, zoomOverride {request.ZoomOverride}");
            _loadRoutine = StartCoroutine(LoadWhenReady(request));
        }

        private IEnumerator LoadWhenReady(MapRequest request)
        {
            int attempts = 0;
            while (mapBackground == null && attempts < backgroundMaxAttempts)
            {
                mapBackground = GetComponentInChildren<MapBackground>();
                if (mapBackground != null)
                {
                    Log($"Found MapBackground after {attempts + 1} attempt(s).");
                    break;
                }
                attempts++;
                yield return new WaitForSeconds(backgroundWaitSeconds);
            }

            if (mapBackground == null)
            {
                Debug.LogWarning("[MapTilerStaticLoader] MapBackground not found after waiting.");
                yield break;
            }

            var widthMeters = request.WidthMeters > 0.01f ? request.WidthMeters : fallbackAreaMeters;
            var heightMeters = request.HeightMeters > 0.01f ? request.HeightMeters : fallbackAreaMeters;
            var resolvedZoom = ResolveZoom(request, widthMeters, heightMeters);
            Log($"Requesting MapTiler map -> center {request.Center.x},{request.Center.y}, zoom {resolvedZoom}, meters {widthMeters}x{heightMeters}, pixels {imageWidth}x{imageHeight}.");

            if (useStaticSnapshots && !_staticForbidden)
            {
                yield return FetchStaticMap(request.Center, resolvedZoom, widthMeters, heightMeters);
            }
            else
            {
                yield return FetchTileSnapshot(request.Center, resolvedZoom);
            }
        }

        private IEnumerator FetchStaticMap(Vector2 centerLatLon, int resolvedZoom, float widthMeters, float heightMeters)
        {
            var lat = centerLatLon.x.ToString(CultureInfo.InvariantCulture);
            var lon = centerLatLon.y.ToString(CultureInfo.InvariantCulture);
            var url = $"https://api.maptiler.com/maps/{styleId}/static/{lon},{lat},{resolvedZoom}/{imageWidth}x{imageHeight}.png?key={apiKey}";
            var maskedUrl = MaskUrl(url);
            Log($"Requesting static map: {maskedUrl} | {DescribeApiKey()}");
            using (var req = UnityWebRequestTexture.GetTexture(url))
            {
                yield return req.SendWebRequest();

                if (req.result != UnityWebRequest.Result.Success)
                {
                    LogMapRequestFailure(req, url);
                    if (fallbackToTileOnStaticError && req.responseCode == 403)
                    {
                        _staticForbidden = true;
                        Log("Static snapshots forbidden for this key/plan; falling back to tile snapshot (free tier).");
                        yield return FetchTileSnapshot(centerLatLon, resolvedZoom);
                    }
                    yield break;
                }

                var tex = DownloadHandlerTexture.GetContent(req);
                tex.wrapMode = TextureWrapMode.Clamp;
                tex.filterMode = FilterMode.Bilinear;
                mapBackground.ApplyTexture(tex, Vector2.one);
                Log($"Applied MapTiler texture {tex.width}x{tex.height} to background.");
                OnTextureApplied?.Invoke(tex);
            }
        }

        private IEnumerator FetchTileSnapshot(Vector2 centerLatLon, int resolvedZoom)
        {
            var (tileX, tileY) = LatLonToTile(centerLatLon, resolvedZoom);
            var url = BuildTileUrl(styleId, resolvedZoom, tileX, tileY);
            var maskedUrl = MaskUrl(url);
            Log($"Requesting tile snapshot: {maskedUrl} (z{resolvedZoom} x{tileX} y{tileY})");
            using (var req = UnityWebRequestTexture.GetTexture(url))
            {
                yield return req.SendWebRequest();

                if (req.result != UnityWebRequest.Result.Success)
                {
                    LogMapRequestFailure(req, url);
                    if (ShouldTryBasicStyle(req.responseCode))
                    {
                        var fallbackStyle = "basic-v2";
                        Log($"Tile endpoint returned {req.responseCode}; retrying with fallback style '{fallbackStyle}'.");
                        var fallbackUrl = BuildTileUrl(fallbackStyle, resolvedZoom, tileX, tileY);
                        _tileStyleFallbackUsed = true;
                        yield return FetchTileSnapshotWithUrl(fallbackUrl, resolvedZoom, tileX, tileY, true);
                    }
                    yield break;
                }

                var tex = DownloadHandlerTexture.GetContent(req);
                tex.wrapMode = TextureWrapMode.Clamp;
                tex.filterMode = FilterMode.Bilinear;
                mapBackground.ApplyTexture(tex, Vector2.one);
                Log($"Applied single-tile snapshot {tex.width}x{tex.height} (free tier) to background.");
                OnTextureApplied?.Invoke(tex);
            }
        }

        private IEnumerator FetchTileSnapshotWithUrl(string url, int resolvedZoom, int tileX, int tileY, bool isFallback)
        {
            var maskedUrl = MaskUrl(url);
            Log($"Requesting tile snapshot{(isFallback ? " (fallback)" : string.Empty)}: {maskedUrl} (z{resolvedZoom} x{tileX} y{tileY})");
            using (var req = UnityWebRequestTexture.GetTexture(url))
            {
                yield return req.SendWebRequest();

                if (req.result != UnityWebRequest.Result.Success)
                {
                    LogMapRequestFailure(req, url);
                    yield break;
                }

                var tex = DownloadHandlerTexture.GetContent(req);
                tex.wrapMode = TextureWrapMode.Clamp;
                tex.filterMode = FilterMode.Bilinear;
                mapBackground.ApplyTexture(tex, Vector2.one);
                Log($"Applied single-tile snapshot {tex.width}x{tex.height}{(isFallback ? " (fallback style)" : string.Empty)} to background.");
                OnTextureApplied?.Invoke(tex);
            }
        }

        public void SetApiKey(string key)
        {
            if (string.IsNullOrWhiteSpace(key))
            {
                return;
            }
            apiKey = key.Trim();
            _apiKeyFromEnv = false;
            Log($"MapTiler API key updated -> {DescribeApiKey()}");
        }

        public void SetGeoReference(GeoReference reference)
        {
            geoReference = reference;
        }

        public void SetStyle(string style)
        {
            if (!string.IsNullOrWhiteSpace(style))
            {
                styleId = style.Trim();
            }
        }

        public void ForceZoomAndStyle(int zoomValue, bool autoCalc, string style)
        {
            zoom = Mathf.Clamp(zoomValue, minZoom, maxZoom);
            autoCalculateZoom = autoCalc;
            if (!string.IsNullOrWhiteSpace(style))
            {
                styleId = style.Trim();
            }
            Log($"Forced zoom/style -> zoom:{zoom}, autoCalc:{autoCalculateZoom}, style:{styleId}");
        }

        private void ApplyForcedZoomSettings()
        {
            if (!forceZoomSettings)
            {
                return;
            }

            zoom = forcedZoom;
            autoCalculateZoom = forcedAutoCalculateZoom;
            if (!string.IsNullOrWhiteSpace(forcedStyleId))
            {
                styleId = forcedStyleId.Trim();
            }
        }

        private void EnsureApiKey()
        {
            if (preferEnvApiKey && !string.IsNullOrEmpty(apiKeyEnvVar))
            {
                var fromEnvPreferred = Environment.GetEnvironmentVariable(apiKeyEnvVar);
                if (!string.IsNullOrEmpty(fromEnvPreferred))
                {
                    apiKey = fromEnvPreferred.Trim();
                    _apiKeyFromEnv = true;
                    Log($"Loaded MapTiler API key from environment variable '{apiKeyEnvVar}' (masked {MaskKey(apiKey)}).");
                    return;
                }
            }

            if (!string.IsNullOrEmpty(apiKey) || string.IsNullOrEmpty(apiKeyEnvVar))
            {
                return;
            }

            var fromEnv = Environment.GetEnvironmentVariable(apiKeyEnvVar);
            if (!string.IsNullOrEmpty(fromEnv))
            {
                apiKey = fromEnv.Trim();
                _apiKeyFromEnv = true;
                Log($"Loaded MapTiler API key from environment variable '{apiKeyEnvVar}' (masked {MaskKey(apiKey)}).");
            }
        }

        private int ResolveZoom(MapRequest request, float widthMeters, float heightMeters)
        {
            if (request.ZoomOverride.HasValue)
            {
                return Mathf.Clamp(request.ZoomOverride.Value, minZoom, maxZoom);
            }

            if (!autoCalculateZoom)
            {
                return Mathf.Clamp(zoom, minZoom, maxZoom);
            }

            var mppX = widthMeters / Mathf.Max(1, imageWidth);
            var mppY = heightMeters / Mathf.Max(1, imageHeight);
            var targetMetersPerPixel = Mathf.Max(mppX, mppY);
            var cosLat = Mathf.Max(0.0001f, Mathf.Cos(request.Center.x * Mathf.Deg2Rad));
            var zoomExact = Math.Log((EarthCircumferenceMeters * cosLat) / (targetMetersPerPixel * TileSize), 2);
            return Mathf.Clamp(Mathf.RoundToInt((float)zoomExact), minZoom, maxZoom);
        }

        private (int x, int y) LatLonToTile(Vector2 latLon, int zoomLevel)
        {
            var latRad = latLon.x * Mathf.Deg2Rad;
            var n = Math.Pow(2.0, zoomLevel);
            var x = (int)Math.Floor((latLon.y + 180.0) / 360.0 * n);
            var y = (int)Math.Floor((1.0 - Math.Log(Math.Tan(latRad) + 1.0 / Math.Cos(latRad)) / Math.PI) / 2.0 * n);
            return (x, y);
        }

        private void Log(string message)
        {
            if (!debugLogging) return;
            Debug.Log($"[MapTilerStaticLoader] {message}");
        }

        private void LogMapRequestFailure(UnityWebRequest req, string url)
        {
            var contentType = req.GetResponseHeader("Content-Type") ?? "(none)";
            var bodySummary = BuildBodyPreview(req, contentType);
            var maskedUrl = MaskUrl(url);
            var rateRemaining = req.GetResponseHeader("X-RateLimit-Remaining");
            var rateReset = req.GetResponseHeader("X-RateLimit-Reset");
            var rateInfo = !string.IsNullOrEmpty(rateRemaining) ? $"rate remaining {rateRemaining}" : "rate remaining n/a";
            if (!string.IsNullOrEmpty(rateReset))
            {
                rateInfo += $", resets {rateReset}";
            }
            var hint = BuildFailureHint(req.responseCode, contentType);
            Debug.LogError($"[MapTilerStaticLoader] Map fetch failed -> status {req.responseCode} ({req.result}), error '{req.error}', content-type '{contentType}', body {bodySummary}, url {maskedUrl}, {DescribeApiKey()}, {rateInfo}. Hint: {hint}");
        }

        private string BuildBodyPreview(UnityWebRequest req, string contentType)
        {
            if (!logErrorBody)
            {
                return "(body logging disabled)";
            }

            var data = req.downloadHandler?.data;
            if (data == null || data.Length == 0)
            {
                return "(empty)";
            }

            const int maxBytes = 256;
            var isText = contentType.IndexOf("json", StringComparison.OrdinalIgnoreCase) >= 0 ||
                         contentType.IndexOf("text", StringComparison.OrdinalIgnoreCase) >= 0 ||
                         contentType.IndexOf("xml", StringComparison.OrdinalIgnoreCase) >= 0;
            if (isText)
            {
                var len = Math.Min(maxBytes, data.Length);
                try
                {
                    var preview = Encoding.UTF8.GetString(data, 0, len);
                    return $"text '{preview}'";
                }
                catch
                {
                    // fall through to binary summary
                }
            }

            var hexLen = Math.Min(32, data.Length);
            var hex = BitConverter.ToString(data, 0, hexLen).Replace("-", "");
            return $"binary {data.Length} bytes (hex {hex})";
        }

        private string BuildFailureHint(long status, string contentType)
        {
            switch (status)
            {
                case 401:
                    return "Unauthorized: key missing/invalid for static maps.";
                case 403:
                    return "Forbidden: key not permitted for this style/domain or quota exhausted; verify billing and static map access.";
                case 404:
                    return "Style or endpoint not found; check styleId.";
                case 429:
                    return "Rate limited; wait or reduce requests.";
            }

            if (contentType.IndexOf("png", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return "Service returned an image error response; likely key/style authorization issue.";
            }

            return "Check MapTiler dashboard for key validity, quotas, and style permissions.";
        }

        private string DescribeApiKey()
        {
            if (string.IsNullOrEmpty(apiKey))
            {
                return "API key empty";
            }

            var source = _apiKeyFromEnv ? $"env '{apiKeyEnvVar}'" : "inspector/runtime field";
            return $"API key set from {source} (len {apiKey.Length}, masked {MaskKey(apiKey)})";
        }

        private string BuildTileUrl(string style, int zoomLevel, int tileX, int tileY)
        {
            // MapTiler raster tile endpoint format: /maps/{style}/{size}/{z}/{x}/{y}.png
            return $"https://api.maptiler.com/maps/{style}/{TileSize}/{zoomLevel}/{tileX}/{tileY}.png?key={apiKey}";
        }

        private bool ShouldTryBasicStyle(long status)
        {
            if (!fallbackToBasicStyleOnTileError)
            {
                return false;
            }

            if (_tileStyleFallbackUsed)
            {
                return false;
            }

            return status == 403 || status == 404;
        }

        private string MaskKey(string key)
        {
            if (string.IsNullOrEmpty(key))
            {
                return "(empty)";
            }

            var trimmed = key.Trim();
            if (trimmed.Length <= KeyRevealCount * 2)
            {
                return $"{trimmed.Substring(0, Math.Min(trimmed.Length, KeyRevealCount))}***";
            }

            var prefix = trimmed.Substring(0, KeyRevealCount);
            var suffix = trimmed.Substring(trimmed.Length - KeyRevealCount, KeyRevealCount);
            return $"{prefix}...{suffix}";
        }

        private string MaskUrl(string url)
        {
            if (string.IsNullOrEmpty(url) || string.IsNullOrEmpty(apiKey))
            {
                return url;
            }

            return url.Replace(apiKey, MaskKey(apiKey));
        }
    }
}
