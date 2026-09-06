# Issue 596 design-system execution

**Role: CURRENT-SCOPED.** The authoritative PRD is [GitHub issue 596](https://github.com/JMLegere/geo-app/issues/596). Execution is tracked in `execution-status.yaml` and draft PR #598.

The previous local implementation was absent when this workspace resumed. All 1,099 source blobs were retrieved and verified against main `f96a841b4eba5468ee9c0958b36c52d67c60b3b7`; the complete tree matches `12ecddcb01920c23c0c3b41b142a026fc78ad90b`. Previous Flutter test counts are not reused for reconstructed code.

## Foundation decision

Use one typed Dart token source. The PRD explicitly permits this alternative to a token compiler. No code-generation exception, build_runner, duplicate JSON token values, new runtime service, or Shad upgrade is introduced. Keep the pinned Shad defaults; centralize EarthNova overrides and recipes behind the public barrel.

## Evidence

`npm run spec:ui596:check` validates 111 Q, 27 A and 12 D records against 59 target Gherkin scenarios. Parsing and traceability are not executed acceptance.

`npm run design:check` rejects new raw presentation values outside the shared library. The exact per-file/source baseline is temporary debt, owned by issue 596 and retired as screens migrate. It is never reset to admit new violations.

The target scenarios imported from draft PR #597 remain specifications until real production-boundary tests or reviewed visuals verify them. Native EAC contracts and Flutter registry parity remain mandatory.
