# Use local fixtures with optional read-only production access

EarthNova agents must use deterministic local fixtures for implementation and CI, while audited least-privilege read-only production access may supplement diagnosis and reality checks but cannot serve as the sole verification evidence. We accept the maintenance cost of local simulation and the controls required for production observability because reproducibility and player-data safety outweigh the convenience of testing against live state; deployment remains separately human-authorized.
