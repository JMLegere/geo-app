using GeoApp.Utilities;
using GeoApp.Domain;
using NUnit.Framework;

namespace GeoApp.Tests
{
    public class GeoUtilsTests
    {
        [Test]
        public void Haversine_ReturnsZero_ForIdenticalPoints()
        {
            var a = new Vector2d(0, 0);
            var b = new Vector2d(0, 0);
            double result = GeoUtils.Haversine(a, b);
            Assert.AreEqual(0d, result, 1e-6);
        }

        [Test]
        public void Haversine_ComputesKnownDistance()
        {
            var a = new Vector2d(0, 0);
            var b = new Vector2d(0, 1);
            double result = GeoUtils.Haversine(a, b);
            Assert.That(result, Is.EqualTo(111195.0).Within(1000));
        }

        [Test]
        public void Haversine_IsSymmetric()
        {
            var a = new Vector2d(52.52, 13.405); // Berlin
            var b = new Vector2d(48.8566, 2.3522); // Paris
            double ab = GeoUtils.Haversine(a, b);
            double ba = GeoUtils.Haversine(b, a);
            Assert.That(ab, Is.EqualTo(ba).Within(1e-6));
        }
    }
}
