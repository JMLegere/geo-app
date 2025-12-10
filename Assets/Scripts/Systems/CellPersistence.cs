using System.Collections.Generic;
using UnityEngine;

namespace GeoApp.Systems
{
    /// <summary>
    /// Minimal local persistence for explored/revealed cells.
    /// </summary>
    public static class CellPersistence
    {
        private const string SaveKey = "geoapp.cells.v1";

        [System.Serializable]
        private class SavePayload
        {
            public List<int> explored = new List<int>();
            public List<int> revealed = new List<int>();
        }

        public static (HashSet<int> explored, HashSet<int> revealed) Load()
        {
            if (!PlayerPrefs.HasKey(SaveKey))
            {
                return (new HashSet<int>(), new HashSet<int>());
            }

            var json = PlayerPrefs.GetString(SaveKey, string.Empty);
            if (string.IsNullOrEmpty(json))
            {
                return (new HashSet<int>(), new HashSet<int>());
            }

            var payload = JsonUtility.FromJson<SavePayload>(json);
            return (new HashSet<int>(payload.explored ?? new List<int>()), new HashSet<int>(payload.revealed ?? new List<int>()));
        }

        public static void Save(HashSet<int> explored, HashSet<int> revealed)
        {
            var payload = new SavePayload
            {
                explored = new List<int>(explored),
                revealed = new List<int>(revealed)
            };

            var json = JsonUtility.ToJson(payload);
            PlayerPrefs.SetString(SaveKey, json);
            PlayerPrefs.Save();
        }
    }
}
