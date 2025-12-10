using System;
using System.Reflection;
using GeoApp.Map;
using NUnit.Framework;
using UnityEngine;

public class MapTilerTests
{
    private const string LegacyKey = "YA13yb8j8V4OehBzdMhC";
    private const string CurrentKey = "ntk9pZ3tCDGGdrzs9ajs";

    [Test]
    public void OnValidate_UpgradesLegacyKey()
    {
        var go = new GameObject("FogOfWorldMvp_Test");
        try
        {
            var mvp = go.AddComponent<FogOfWorldMvp>();
            var keyField = typeof(FogOfWorldMvp).GetField("mapTilerApiKey", BindingFlags.NonPublic | BindingFlags.Instance);
            Assert.IsNotNull(keyField, "mapTilerApiKey field should exist.");
            keyField.SetValue(mvp, LegacyKey);

            var onValidate = typeof(FogOfWorldMvp).GetMethod("OnValidate", BindingFlags.NonPublic | BindingFlags.Instance);
            Assert.IsNotNull(onValidate, "OnValidate should exist.");
            onValidate.Invoke(mvp, null);

            var updated = (string)keyField.GetValue(mvp);
            Assert.AreEqual(CurrentKey, updated, "Legacy key should be upgraded to the current default.");
        }
        finally
        {
            UnityEngine.Object.DestroyImmediate(go);
        }
    }

    [Test]
    public void EnsureApiKey_PrefersEnvironmentVariable()
    {
        const string envVarName = "MAPTILER_API_KEY";
        const string envValue = "from-env-key";
        var previousEnv = Environment.GetEnvironmentVariable(envVarName);
        Environment.SetEnvironmentVariable(envVarName, envValue);

        var go = new GameObject("MapTilerStaticLoader_Test");
        try
        {
            var loader = go.AddComponent<MapTilerStaticLoader>();

            var apiKeyField = typeof(MapTilerStaticLoader).GetField("apiKey", BindingFlags.NonPublic | BindingFlags.Instance);
            apiKeyField.SetValue(loader, "from-inspector");

            var preferEnvField = typeof(MapTilerStaticLoader).GetField("preferEnvApiKey", BindingFlags.NonPublic | BindingFlags.Instance);
            preferEnvField.SetValue(loader, true);

            var ensureApiKey = typeof(MapTilerStaticLoader).GetMethod("EnsureApiKey", BindingFlags.NonPublic | BindingFlags.Instance);
            Assert.IsNotNull(ensureApiKey, "EnsureApiKey should exist.");
            ensureApiKey.Invoke(loader, null);

            var apiKey = (string)apiKeyField.GetValue(loader);
            var fromEnvField = typeof(MapTilerStaticLoader).GetField("_apiKeyFromEnv", BindingFlags.NonPublic | BindingFlags.Instance);
            var fromEnv = (bool)fromEnvField.GetValue(loader);

            Assert.AreEqual(envValue, apiKey, "Environment value should override inspector key when preferEnvApiKey is true.");
            Assert.IsTrue(fromEnv, "Key source flag should mark environment usage.");
        }
        finally
        {
            Environment.SetEnvironmentVariable(envVarName, previousEnv);
            UnityEngine.Object.DestroyImmediate(go);
        }
    }
}
