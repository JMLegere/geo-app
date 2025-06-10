namespace GeoApp.Domain
{
    public interface ILocationService
    {
        bool IsEnabledByUser { get; }
        LocationStatus Status { get; }
        void Start(double desiredAccuracyInMeters, double updateDistanceInMeters);
        (double latitude, double longitude) LastData { get; }
    }
}
