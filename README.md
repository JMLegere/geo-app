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

## Continuous Integration

This repository uses [GitHub Actions](.github/workflows/dotnet.yml) to
run unit tests and build the Unity project on each pull request.
The workflow requires Unity credentials provided as GitHub secrets in
order to activate the editor during CI.
To run the Unity build job you must provide the following secrets in your
repository settings:

- `UNITY_EMAIL` – Unity account email used for activation
- `UNITY_PASSWORD` – password for the account
- `UNITY_LICENSE` – contents of your `.ulf` license file <strong>or</strong>
- `UNITY_SERIAL` – your serial key

If neither `UNITY_LICENSE` nor `UNITY_SERIAL` is present the activation step
will fail and the workflow will stop early. For a personal license generate the
`.ulf` file locally and store it in the `UNITY_LICENSE` secret.

These secrets must be stored in an environment named **Unity Secrets** so that
the workflow can access them during CI.

After Unity activates, the build is compiled and uploaded as a workflow
artifact so you can download it from the Actions run summary.

The workflow automatically uses the latest Unity Docker image. No Unity version
needs to be specified in the configuration.

Set the `DOCKER_CLI_DEBUG` variable to `1` in the workflow if you need verbose
Docker output during activation.

When debugging activation failures check the log output from the
`Verify Unity secrets` step. It prints the length and SHA‑1 hash of each
secret so you can confirm the workflow received them. If the lengths are zero,
ensure the **Unity Secrets** environment is configured for the workflow and
that pull requests are allowed to access it. The `UNITY_LICENSE` secret should
contain the entire contents of your `.ulf` file.
