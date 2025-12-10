using GeoApp.Map;
using UnityEngine;

namespace GeoApp.View
{
    /// <summary>
    /// Renders a single cell polygon.
    /// </summary>
    [RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
    public class CellVisual : MonoBehaviour
    {
        public int CellId { get; private set; }

        private Mesh _mesh;
        private MeshFilter _meshFilter;
        private MeshRenderer _meshRenderer;

        public void Initialize(int cellId, Vector3[] vertices, int[] triangles, Material sharedMaterial)
        {
            CellId = cellId;
            _meshFilter = GetComponent<MeshFilter>();
            _meshRenderer = GetComponent<MeshRenderer>();
            _meshRenderer.sharedMaterial = sharedMaterial;

            _mesh = new Mesh
            {
                name = $"cell_{cellId}"
            };
            _mesh.SetVertices(vertices);
            _mesh.SetTriangles(triangles, 0);
            _mesh.RecalculateNormals();
            _mesh.RecalculateBounds();

            _meshFilter.sharedMesh = _mesh;
        }

        public void SetColor(Color color)
        {
            var block = new MaterialPropertyBlock();
            _meshRenderer.GetPropertyBlock(block);
            block.SetColor("_BaseColor", color);
            block.SetColor("_Color", color);
            _meshRenderer.SetPropertyBlock(block);
        }

        private void OnDestroy()
        {
            if (_mesh != null)
            {
                Destroy(_mesh);
            }
        }
    }
}
