using System.Collections;
using GeoApp.Domain;
using GeoApp.Infrastructure;
using NUnit.Framework;

namespace GeoApp.Tests
{
    class FakeService : ILocationService
    {
        public bool IsEnabledByUser { get; set; } = true;
        public LocationStatus Status { get; set; } = LocationStatus.Stopped;
        public (double latitude, double longitude) LastData { get; set; }

        public void Start(double desiredAccuracyInMeters, double updateDistanceInMeters)
        {
            Status = LocationStatus.Initializing;
        }
    }

    public class LocationServiceRunnerTests
    {
        [Test]
        public void Initialize_InvokesCallback_WhenServiceBecomesRunning()
        {
            var service = new FakeService();
            var runner = new LocationServiceRunner(service);
            bool called = false;
            IEnumerator routine = runner.Initialize(() => called = true);

            Assert.IsTrue(routine.MoveNext());
            Assert.AreEqual(LocationStatus.Initializing, service.Status);
            Assert.IsFalse(called);

            service.Status = LocationStatus.Running;
            Assert.IsFalse(routine.MoveNext());
            Assert.IsTrue(called);
        }

        [Test]
        public void Initialize_Stops_WhenServiceDisabled()
        {
            var service = new FakeService { IsEnabledByUser = false };
            var runner = new LocationServiceRunner(service);
            bool called = false;
            IEnumerator routine = runner.Initialize(() => called = true);
            Assert.IsFalse(routine.MoveNext());
            Assert.IsFalse(called);
        }
    }
}
