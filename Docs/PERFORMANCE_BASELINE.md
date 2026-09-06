# Performance baseline record — issue #45

**No physical performance baseline has been captured. #45 remains incomplete.**
The [budgets and capture checklist](PERFORMANCE_BUDGETS.md) are preparation for
physical profiling, not a passing baseline. Simulator unit tests cannot verify
frame pacing, thermal behavior, battery use or physical GPU resource consumption.

## Preparation evidence, 2026-09-06

- Source inspected: `233967ee826f4eccbeb4d36b38d312e70cd141c4` (main), Xcode 26.6
  (17F113). No profiled Release build has been produced for this record.
- `xcrun devicectl list devices --timeout 15` found a paired iPhone 17 Pro and
  watch; no iPad. `xcrun xctrace list devices` initially listed the phone offline.
- A subsequent `xcrun devicectl device info details --device <device-id> --timeout 15`
  succeeded: physical iPhone 17 Pro, iOS 26.6.1 (23G83), Developer Mode enabled,
  network tunnel connected. Personal identifiers are intentionally omitted.
- The owner reports an iPhone 15 and iPhone 17 Pro available for testing, and no
  iPad. The older supported-phone range and physical tablet baseline remain gaps.
- Static inspection: six plots, shared procedural meshes/materials, two directional
  lights (one shadowed), nine particles per harvest with 0.85-second lifetime.
  No scene image textures are assigned by `FarmEntityFactory`; this does not imply
  zero GPU texture allocation (render targets/shadows must be measured).
- `FarmView` passes inactive when a sheet is shown or scene phase is not active.
  `FarmSceneController.setActive` cancels its update subscription and clears
  particles. No physical trace verifies callback cessation or residual GPU cost.

Potential investigation points are shadow passes, mature crop geometry, and GPU
activity behind sheets. **None is an established bottleneck.** Do not optimize or
file speculative defect claims from these observations alone.

## Local validation, 2026-09-06

- `make test`: exit 0, **TEST SUCCEEDED**, 62 tests, 0 failures (0 unexpected).
- `make ci-local`: exit 0, **TEST SUCCEEDED**, 62 tests, 0 failures (0 unexpected).
  Xcode 26.6 (17F113), Swift 6.3.3, XcodeGen 2.46.0; default iPhone 17 Pro
  simulator destination, Debug configuration, code signing disabled.
- `xcodegen generate` and `git diff --check`: passed. All 12 local Markdown
  links in the three changed documents resolve.
- Review: documentation only; no gameplay rules, save schema, network behavior,
  player-facing strings, accessibility controls or generated files changed in Git.
  No new unit tests are warranted for this documentation-only checkpoint.

These checks validate repository health, not physical-device performance.

## Acceptance status

| #45 acceptance check | Status |
| --- | --- |
| Physical baselines with build configuration and OS versions | Blocked: capture/operator session and physical iPad required |
| Explicit M1 and projected expansion budgets | Provisional ceilings documented; physical calibration pending |
| No sustained gesture / harvest hitching | Unverified |
| Background/inactive rendering verified | Source inspected only; physical verification pending |
| Asset, expansion and effect issues reference budgets | Dependency mapping prepared; issue updates pending validated baseline |

## Per-device result template

Copy this section for each device and repeat. Use **not measured** for missing
results; never enter zero or pass for unavailable metrics. Include every scenario
ID from the checklist and link each reported value to evidence.

- Operator/date:
- Commit SHA and clean/dirty state:
- Device model / OS version and build:
- App version/build, Xcode, Release optimization settings:
- Resolution/refresh rate/orientation:
- Locale/text size/VoiceOver/Reduce Motion:
- Ambient temperature, brightness, initial/final thermal state:
- Battery health, initial/final charge, charging/network conditions:
- Tools/versions, trace/video links, selected timestamp intervals:
- Launch samples (5 reboot-cold + 5 process-cold), video timing uncertainty:

| Scenario / repeat / crop | Duration | Frame interval p50/p95/p99/max; % >25 ms | Worst rolling 1 s mean | CPU/GPU p95 ms | Memory steady/peak/retained MiB | Draws/triangles | Texture MiB/max dimensions | Result/evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Not measured | — | — | — | — | — | — | — | Pending |

- Installed Release .app bytes / optional thinned download bytes:
- Thermal transition timestamps, final 5-minute frame metrics:
- Three 30-minute battery runs + idle controls (raw and adjusted losses):
- Inactive/background callback and GPU evidence; sheet residual GPU cost:
- Reduce Motion, VoiceOver, English/Portuguese interaction observations:
- Failed budget / reproducible steps / focused follow-up link:
- Overall decision (pass / fail / incomplete), reviewer/date:

## Remaining steps

1. Connect the iPhone 15 and iPhone 17 Pro, confirm an operator for gestures and
   unplugged runs, and arrange a physical iPad; record exact OS builds.
2. Generate the Xcode project and prepare a locally signed Release build from
   the feature branch without committing signing settings or generated files.
3. Run the full checklist on each physical device; retain sanitized evidence and
   fill the per-device records. Record older-phone coverage as unverified unless
   those devices are also tested.
4. Identify measured bottlenecks and file focused follow-ups, if any. Reconcile
   the provisional ceilings with evidence and repeat failed captures as needed.
5. Add the validated document links to the dependency issues listed in the budget
   document; verify all #45 acceptance checks before marking its PR ready.
6. Run `make test` and `make ci-local` after any subsequent implementation changes,
   review scope/save compatibility/localization/accessibility/generated files,
   commit and push the final evidence, then mark the PR ready to close #45.

Next command when resuming: `xcrun devicectl list devices --timeout 15`.
