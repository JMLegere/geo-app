namespace GeoApp.Domain
{
    /// <summary>
    /// Simple immutable double precision 2D vector.
    /// </summary>
    public readonly struct Vector2d
    {
        public readonly double x;
        public readonly double y;

        public Vector2d(double x, double y) => (this.x, this.y) = (x, y);
    }
}
