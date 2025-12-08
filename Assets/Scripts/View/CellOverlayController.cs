using System.Collections.Generic;
using GeoApp.Map;
using GeoApp.Systems;
using UnityEngine;

namespace GeoApp.View
{
    /// <summary>
    /// Builds and updates visible cells.
    /// </summary>
    public class CellOverlayController : MonoBehaviour
    {
        [Header("Appearance")]
        [SerializeField] private Color fogBaseColor = new Color(0f, 0f, 0f, 1f);
        [SerializeField, Range(0f, 1f)] private float unexploredAlpha = 1.0f;   // 100% opaque
        [SerializeField, Range(0f, 1f)] private float revealedAlpha = 0.7f;   // 70% opaque
        [SerializeField, Range(0f, 1f)] private float exploredAlpha = 0.4f;   // 40% opaque
        [SerializeField, Range(0f, 1f)] private float presentAlpha = 0.0f;    // 0% opaque

        private readonly Dictionary<int, CellVisual> _visuals = new Dictionary<int, CellVisual>();
        private Material _material;

        public void BuildCells(IEnumerable<CellData> cells, GeoReference geoReference, CellStateSystem stateSystem)
        {
            EnsureMaterial();
            foreach (var cell in cells)
            {
                var vertices = BuildVertices(cell, geoReference);
                var triangles = BuildTriangles(cell);
                var go = new GameObject($"cell_{cell.Id}");
                go.transform.SetParent(transform, false);
                var visual = go.AddComponent<CellVisual>();
                visual.Initialize(cell.Id, vertices, triangles, _material);
                visual.SetColor(ColorForState(cell.State));
                _visuals[cell.Id] = visual;
            }

            stateSystem.OnCellStateChanged += HandleCellStateChanged;
        }

        public void UpdatePlayerMarker(GameObject marker, Vector3 worldPos)
        {
            if (marker != null)
            {
                marker.transform.position = worldPos + Vector3.up * 0.1f;
            }
        }

        private void HandleCellStateChanged(CellData cell)
        {
            if (_visuals.TryGetValue(cell.Id, out var visual))
            {
                visual.SetColor(ColorForState(cell.State));
            }
        }

        private Color ColorForState(CellState state)
        {
            var baseCol = fogBaseColor;
            switch (state)
            {
                case CellState.Revealed:
                    baseCol.a = revealedAlpha;
                    return baseCol;
                case CellState.Explored:
                    baseCol.a = exploredAlpha;
                    return baseCol;
                case CellState.Present:
                    baseCol.a = presentAlpha;
                    return baseCol;
                default:
                    baseCol.a = unexploredAlpha;
                    return baseCol;
            }
        }

        private Vector3[] BuildVertices(CellData cell, GeoReference geoReference)
        {
            var verts = new Vector3[cell.PolygonMeters.Length];
            var scale = 1f / geoReference.MetersPerUnityUnit;
            for (int i = 0; i < cell.PolygonMeters.Length; i++)
            {
                var m = cell.PolygonMeters[i];
                verts[i] = new Vector3(m.x * scale, 0f, m.y * scale);
            }
            return verts;
        }

        private int[] BuildTriangles(CellData cell)
        {
            // Fan triangulation around vertex 0 (convex polygons).
            var triCount = (cell.PolygonMeters.Length - 2) * 3;
            var triangles = new int[triCount];
            int idx = 0;
            for (int i = 1; i < cell.PolygonMeters.Length - 1; i++)
            {
                triangles[idx++] = 0;
                triangles[idx++] = i;
                triangles[idx++] = i + 1;
            }
            return triangles;
        }

        private void EnsureMaterial()
        {
            if (_material != null)
            {
                return;
            }

            var shader = Shader.Find("Universal Render Pipeline/Unlit");
            if (shader == null)
            {
                shader = Shader.Find("Unlit/Color");
            }

            _material = new Material(shader)
            {
                name = "CellOverlayMaterial",
                renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent
            };
            _material.enableInstancing = true;
            // Force transparent rendering so fog alpha lets the map show through.
            _material.SetFloat("_Surface", 1f); // Transparent
            _material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
            _material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
            _material.SetInt("_ZWrite", 0);
            _material.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");
            _material.DisableKeyword("_ALPHATEST_ON");
            _material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
        }
    }
}
