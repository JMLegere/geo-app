using UnityEngine;

namespace GeoApp.Map
{
    /// <summary>
    /// Builds a simple quad background to stand in for the world map.
    /// </summary>
    [RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
    public class MapBackground : MonoBehaviour
    {
        [SerializeField] private Color baseColor = new Color(0.15f, 0.18f, 0.2f, 1f);
        [SerializeField] private Color gridColor = new Color(0.75f, 0.78f, 0.82f, 0.8f);
        [SerializeField] private float gridStepMeters = 200f;

        private Mesh _mesh;
        private MeshFilter _meshFilter;
        private MeshRenderer _meshRenderer;
        private Material _material;
        private float _widthMeters;
        private float _heightMeters;

        public float WidthMeters => _widthMeters;
        public float HeightMeters => _heightMeters;

        public void Initialize(float widthMeters, float heightMeters, float metersPerUnit)
        {
            _widthMeters = widthMeters;
            _heightMeters = heightMeters;
            _meshFilter = GetComponent<MeshFilter>();
            _meshRenderer = GetComponent<MeshRenderer>();

            var shader = Shader.Find("Universal Render Pipeline/Unlit");
            if (shader == null)
            {
                shader = Shader.Find("Unlit/Color");
            }

            _material = new Material(shader) { name = "MapBackgroundMat" };
            _material.color = baseColor;
            _meshRenderer.sharedMaterial = _material;

            BuildQuad(widthMeters, heightMeters, metersPerUnit);
            ApplyGridTexture(_material, widthMeters, heightMeters);
        }

        private void BuildQuad(float widthMeters, float heightMeters, float metersPerUnit)
        {
            var halfW = widthMeters * 0.5f / metersPerUnit;
            var halfH = heightMeters * 0.5f / metersPerUnit;

            var verts = new[]
            {
                new Vector3(-halfW, 0f, -halfH),
                new Vector3(-halfW, 0f, halfH),
                new Vector3(halfW, 0f, halfH),
                new Vector3(halfW, 0f, -halfH)
            };
            var tris = new[] { 0, 1, 2, 0, 2, 3 };
            var uv = new[]
            {
                new Vector2(0f, 0f),
                new Vector2(0f, 1f),
                new Vector2(1f, 1f),
                new Vector2(1f, 0f)
            };

            _mesh = new Mesh { name = "MapBackgroundMesh" };
            _mesh.SetVertices(verts);
            _mesh.SetTriangles(tris, 0);
            _mesh.SetUVs(0, uv);
            _mesh.RecalculateNormals();
            _mesh.RecalculateBounds();
            _meshFilter.sharedMesh = _mesh;
        }

        private void ApplyGridTexture(Material mat, float widthMeters, float heightMeters)
        {
            // Generate a small checker/grid texture for visibility.
            const int texSize = 64;
            var tex = new Texture2D(texSize, texSize, TextureFormat.RGBA32, false)
            {
                wrapMode = TextureWrapMode.Repeat,
                filterMode = FilterMode.Bilinear,
                name = "MapBackgroundGrid"
            };

            var pixels = new Color32[texSize * texSize];
            for (int y = 0; y < texSize; y++)
            {
                for (int x = 0; x < texSize; x++)
                {
                    bool line = (x % 8 == 0) || (y % 8 == 0);
                    pixels[y * texSize + x] = line ? (Color32)gridColor : (Color32)baseColor;
                }
            }
            tex.SetPixels32(pixels);
            tex.Apply();

            mat.mainTexture = tex;

            // Tile the texture roughly every gridStepMeters in world space.
            var tilesX = Mathf.Max(1f, widthMeters / gridStepMeters);
            var tilesY = Mathf.Max(1f, heightMeters / gridStepMeters);
            mat.mainTextureScale = new Vector2(tilesX, tilesY);
        }

        /// <summary>
        /// Override the background with an external texture (e.g., MapTiler static map).
        /// </summary>
        public void ApplyTexture(Texture2D tex, Vector2? tiling = null)
        {
            if (tex == null || _material == null)
            {
                return;
            }

            _material.mainTexture = tex;
            _material.color = Color.white;
            _material.mainTextureScale = tiling ?? Vector2.one;
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
