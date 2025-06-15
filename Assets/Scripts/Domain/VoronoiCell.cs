using System.Collections.Generic;

namespace GeoApp.Domain
{
    public enum CellState
    {
        Unrevealed,
        Shadowed,
        Revealed
    }

    public class VoronoiCell
    {
        public int index;
        public List<Vector2d> polygon { get; } = new();
        public CellState state = CellState.Unrevealed;
    }
}
