# Geo App

This repository contains a minimal Unity project skeleton for a geolocation game.  
The game is built around GPS-driven exploration with a Voronoi-based fog of war and simple waypoint discovery.

The main scripts live under `Assets/Scripts`:

- **Controllers** – runtime controllers like `LocationController` and `WaypointController`.
- **Infrastructure** – wrappers for external libraries and rendering helpers.
- **Domain** – plain C# types used across the project.
- **Utilities** – helper functions such as the Haversine distance formula.
- **Core** – the `GameManager` that ties everything together.

Waypoints are loaded from `Assets/Resources/WaypointsData.json` and discovered locally on the device.

This project purposely omits networking or cloud features so it can run entirely offline while testing the core gameplay loop.

## Running the tests

Ensure you have the .NET 6 SDK installed to run the unit tests.
Use the .NET CLI to execute unit tests from the repository root:

```bash
dotnet test Tests/GeoApp.Tests/GeoApp.Tests.csproj -v minimal
```