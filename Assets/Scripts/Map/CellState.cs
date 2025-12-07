using System;

namespace GeoApp.Map
{
    /// <summary>
    /// Four-state model for Voronoi cells.
    /// </summary>
    [Serializable]
    public enum CellState
    {
        Unexplored = 0,
        Revealed = 1,
        Explored = 2,
        Present = 3
    }
}
