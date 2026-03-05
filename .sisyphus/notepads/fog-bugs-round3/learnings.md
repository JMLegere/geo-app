
## Task 3 — Deploy + Verify (2026-03-05)

### Railway Deployment
- `railway up --ci` exits 0 cleanly
- Flutter web build includes Wasm dry run warning (benign — not using --wasm flag)
- Font tree-shaking reduces MaterialIcons from 1.6MB to 9.5KB (99.4% reduction)
- Build time ~53s on Metal builder

### Bug A Verification Pattern
Key console signals confirming the broadcast stream fix works:
```
[LOC] #1 from keyboard → (45.9636, -66.6431)
[RUBBER] INIT first target received: (45.963...)
```
Both lines appear on EVERY page load — no user input needed. This is the definitive proof the fix works.

### Bug B Visual Evidence
After movement: three distinct fog zones visible in screenshot:
- Observed: white (~5% opacity)
- Concealed: medium gray (~50% opacity) — the pre-rendered mid-fog showing through the base-fog hole
- Unexplored: dark navy (~95% opacity) — opaque base fog with pre-rendered mid-fog hidden below

### No-Flash Evidence Approach
Can't directly measure "no flash" via screenshots — too slow. Instead:
1. Take screenshot during movement → no jarring transitions visible
2. Count fog update completions — 30+ updates with 0 errors = stable
3. Mechanistic argument: pre-rendering ensures atomic single-source update

### Playwright Gotcha — Auto-Keypress
When using `browser_evaluate` with `Object.getOwnPropertyNames(window)`, Playwright
may focus the canvas and trigger key repeat events. The ArrowDown/ArrowLeft/ArrowRight
keys fire repeatedly during evaluate calls. This caused unintended player movement
during the QA session — harmless for these tests but worth noting for precise scenarios.
