using System.Collections.Generic;

namespace GeoApp.Domain
{
    public enum CellState { Unrevealed, Shadowed, Revealed }

    public class VoronoiCell
    {
        public int index;
        public List<Vector2d> polygon = new List<Vector2d>();
        public CellState state = CellState.Unrevealed;
    }
}
