using System.Collections.Generic;
using UnityEngine;
using GeoApp.Domain;

namespace GeoApp.Infrastructure
{
    public class FogRenderer : MonoBehaviour
    {
        public Material unrevealedMat;
        public Material shadowedMat;
        public Material revealedMat;

        private readonly List<GameObject> _cells = new();

        public void RenderCells(IEnumerable<VoronoiCell> cells)
        {
            foreach (var cell in cells)
            {
                // TODO: build mesh from cell.polygon
                var go = new GameObject($"Cell_{cell.index}");
                go.transform.parent = transform;
                var renderer = go.AddComponent<MeshRenderer>();
                renderer.material = MaterialForState(cell.state);
                _cells.Add(go);
            }
        }

        Material MaterialForState(CellState state) => state switch
        {
            CellState.Shadowed => shadowedMat,
            CellState.Revealed => revealedMat,
            _ => unrevealedMat
        };
    }
}
