using System;
using System.Collections;
using GeoApp.Map;
using UnityEngine;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

namespace GeoApp.Systems
{
    /// <summary>
    /// Uses device GPS when available, otherwise simulates motion for editor testing.
    /// </summary>
    public class PlayerLocationTracker : MonoBehaviour
    {
        [Header("GPS")]
        [SerializeField] private bool useLocationService = true;
        [SerializeField] private float desiredAccuracyMeters = 10f;
        [SerializeField] private float updateDistanceMeters = 5f;
        [SerializeField] private float locationTimeoutSeconds = 15f;

        [Header("Simulation (Editor/Desktop)")]
        [SerializeField] private bool allowSimulation = true;
        [SerializeField] private Vector2 simulatedStartLatLon = new Vector2(37.7749f, -122.4194f);
        [SerializeField] private float simulatedMoveSpeedMps = 5f;
        [SerializeField] private bool randomWalkWhenIdle = true;
        [SerializeField] private float randomWalkSpeedMps = 1.5f;
        [SerializeField] private float randomWalkDirectionSeconds = 3f;
        [SerializeField] private bool debugLogging = false;

        public event Action<Vector2> OnLocationUpdated;
        public event Action<Vector2> OnLocationReady;

        public Vector2 CurrentLatLon { get; private set; }
        public Vector2 CurrentOffsetMeters { get; private set; }
        public bool UsingGps { get; private set; }
        public bool HasLocation { get; private set; }

        private Coroutine _gpsRoutine;
        private Vector2 _randomDir = Vector2.zero;
        private float _randomDirTimer = 0f;
        private float _lastUpdateLogTime = 0f;
        private Vector2 _simulatedOffsetMeters;

        private void Start()
        {
            CurrentLatLon = simulatedStartLatLon;
            _simulatedOffsetMeters = Vector2.zero;
            CurrentOffsetMeters = _simulatedOffsetMeters;
            _gpsRoutine = StartCoroutine(InitializeGps());
            Log("Start() completed, waiting for location.");
        }

        private void OnValidate()
        {
            if (Application.isEditor)
            {
                debugLogging = true;
            }
            simulatedMoveSpeedMps = Mathf.Max(0.1f, simulatedMoveSpeedMps);
            randomWalkSpeedMps = Mathf.Max(0.1f, randomWalkSpeedMps);
            randomWalkDirectionSeconds = Mathf.Max(0.5f, randomWalkDirectionSeconds);
        }

        private IEnumerator InitializeGps()
        {
            // In editor/desktop, skip GPS and simulate.
            if (Application.isEditor && allowSimulation)
            {
                Log("Editor mode: skipping GPS, using simulation.");
                FallbackToSimulation();
                yield break;
            }

            if (!useLocationService || !Input.location.isEnabledByUser)
            {
                Log("Location service disabled or unavailable, using simulation.");
                FallbackToSimulation();
                yield break;
            }

            Input.location.Start(desiredAccuracyMeters, updateDistanceMeters);
            float timer = 0f;
            while (Input.location.status == LocationServiceStatus.Initializing && timer < locationTimeoutSeconds)
            {
                timer += Time.deltaTime;
                yield return null;
            }

            if (Input.location.status != LocationServiceStatus.Running)
            {
                Log("Location service failed to start, using simulation.");
                FallbackToSimulation();
                yield break;
            }

            UsingGps = true;
            HasLocation = true;
            UpdateFromGps();
            OnLocationReady?.Invoke(CurrentLatLon);
            Log($"GPS ready: {CurrentLatLon}");

            while (UsingGps && Input.location.status == LocationServiceStatus.Running)
            {
                UpdateFromGps();
                yield return new WaitForSeconds(0.5f);
            }
        }

        private void UpdateFromGps()
        {
            var data = Input.location.lastData;
            CurrentLatLon = new Vector2(data.latitude, data.longitude);
            HasLocation = true;
            OnLocationUpdated?.Invoke(CurrentLatLon);
            Log($"GPS update -> lat {CurrentLatLon.x}, lon {CurrentLatLon.y}");
        }

        private void FallbackToSimulation()
        {
            UsingGps = false;
            HasLocation = true;
            _simulatedOffsetMeters = Vector2.zero;
            CurrentOffsetMeters = _simulatedOffsetMeters;
            if (Application.isEditor)
            {
                randomWalkWhenIdle = true;
            }
            OnLocationReady?.Invoke(CurrentLatLon);
            Log($"Simulation ready at start lat {CurrentLatLon.x}, lon {CurrentLatLon.y}");
        }

        private void Update()
        {
            if (UsingGps || !allowSimulation)
            {
                Log("Update skipped (UsingGps or allowSimulation false).");
                return;
            }

            var input = ReadSimulatedInput();
            if (input.sqrMagnitude < 0.0001f)
            {
                if (!randomWalkWhenIdle)
                {
                    Log("Simulation idle: no input and random walk disabled.");
                    return;
                }

                UpdateRandomDirection();
                input = _randomDir;
            }

            var meters = input.normalized * simulatedMoveSpeedMps * Time.deltaTime;
            if (input == _randomDir)
            {
                meters = _randomDir * randomWalkSpeedMps * Time.deltaTime;
            }
            _simulatedOffsetMeters += meters;
            CurrentOffsetMeters = _simulatedOffsetMeters;
            CurrentLatLon = GeoUtils.OffsetLatLon(simulatedStartLatLon, _simulatedOffsetMeters);
            OnLocationUpdated?.Invoke(CurrentLatLon);
            if (Time.unscaledTime - _lastUpdateLogTime > 0.5f)
            {
                Log($"Sim update -> lat {CurrentLatLon.x}, lon {CurrentLatLon.y}, dir {input}, metersStep {meters.magnitude}, offset {CurrentOffsetMeters}");
                _lastUpdateLogTime = Time.unscaledTime;
            }
        }

        private void OnDestroy()
        {
            if (_gpsRoutine != null)
            {
                StopCoroutine(_gpsRoutine);
            }

            if (UsingGps)
            {
                Input.location.Stop();
            }
        }

        private Vector2 ReadSimulatedInput()
        {
#if ENABLE_INPUT_SYSTEM
            var keyboard = Keyboard.current;
            if (keyboard == null)
            {
                return Vector2.zero;
            }

            var x = (keyboard.leftArrowKey.isPressed || keyboard.aKey.isPressed ? -1f : 0f) +
                    (keyboard.rightArrowKey.isPressed || keyboard.dKey.isPressed ? 1f : 0f);
            var y = (keyboard.downArrowKey.isPressed || keyboard.sKey.isPressed ? -1f : 0f) +
                    (keyboard.upArrowKey.isPressed || keyboard.wKey.isPressed ? 1f : 0f);
            return new Vector2(x, y).normalized;
#else
            return new Vector2(Input.GetAxisRaw("Horizontal"), Input.GetAxisRaw("Vertical"));
#endif
        }

        private void UpdateRandomDirection()
        {
            _randomDirTimer -= Time.deltaTime;
            if (_randomDirTimer <= 0f || _randomDir == Vector2.zero)
            {
                var angle = UnityEngine.Random.Range(0f, Mathf.PI * 2f);
                _randomDir = new Vector2(Mathf.Cos(angle), Mathf.Sin(angle));
                _randomDirTimer = Mathf.Max(0.5f, randomWalkDirectionSeconds);
                Log($"Random walk direction set to angle {angle} rad, dir {_randomDir}");
            }
        }

        private void Log(string message)
        {
            if (!debugLogging)
            {
                return;
            }

            Debug.Log($"[PlayerLocationTracker] {message}");
        }
    }
}
