# Physical-device performance — issue #45

Status: **profiling preparation; physical baseline and acceptance remain pending**.
These are provisional engineering ceilings, not measured results or evidence that
the current scene meets them. Validate them before broad authored-asset replacement
or scene expansion, in the order defined by [roadmap #52](https://github.com/csambrosio01/fazendinha/issues/52).

## Device matrix

| Role | Device | OS for the baseline | Availability on 2026-09-06 |
| --- | --- | --- | --- |
| Oldest available phone | iPhone 15 | Record installed version and build before capture | Owner has one; not connected during discovery |
| Lower-bound tablet candidate | iPad (9th generation) | Record installed version and build before capture | No physical iPad available |
| Current phone | iPhone 17 Pro | iOS 26.6.1 (23G83) | CoreDevice confirmed physical device, Developer Mode enabled, network tunnel connected |

The iPhone 15 is the owner's available comparison device, **not the minimum
hardware supported by the iOS 17 deployment target**. Coverage of older supported
phones remains unverified. The iPad choice is a test target, not a change to device
support. Do not substitute a simulator or extrapolate phone results for tablet
sign-off. Initial Instruments discovery listed the paired phone offline; later
CoreDevice discovery succeeded. Neither discovery command is a performance capture.

## Budgets

All limits apply on each physical device, at its native rendering resolution.
Use a 60 Hz comparison run where the OS offers that setting and record the actual
refresh rate; also inspect default ProMotion behavior on the current phone.
Time and resource limits apply to the worst repeat, not the average device.

| Metric | M1: current six-plot scene | Projected expansion envelope |
| --- | --- | --- |
| Cold launch to first app frame | <= 2 seconds, worst of 5 reboot-cold launches | Same |
| Launch to interactive farm | <= 3 seconds, worst of 5 reboot-cold launches | Same |
| Active presentation intervals at 60 Hz | p95 <= 18 ms, p99 <= 33.4 ms; <= 1% over 25 ms | Same |
| Gesture / harvest hitches | No interval > 100 ms and no 1-second rolling average > 20 ms during the interaction | Same |
| CPU frame work / GPU frame work | p95 <= 8 ms / <= 12 ms, measured separately | Same |
| App physical memory footprint | <= 250 MiB steady; <= 300 MiB peak | <= 350 MiB steady; <= 400 MiB peak |
| Memory after 20 harvest/replant + sheet cycles | <= 10 MiB above warmed starting footprint after 60 seconds idle; no monotonic retained growth | Same |
| Draw calls, including shadow passes | <= 250 per captured frame | <= 350 per captured frame |
| Submitted triangles, including repeated passes | <= 150,000 per captured frame | <= 250,000 per captured frame |
| Resident scene texture allocation | <= 64 MiB; individual authored texture <= 2048 × 2048 | <= 96 MiB; same individual limit |
| Installed Release .app size, uncompressed | <= 100 MiB | <= 150 MiB |
| Thermal state in 30 minutes of play | No serious/critical state; last 5 minutes still meet frame budgets | Same |
| Battery loss in 30 minutes, unplugged | <= 8 percentage points; report idle-control loss and battery health too | Same |
| Background/inactive scene work | No recurring app animation callback or app GPU submissions after transition settles (2 seconds) | Same |
| Market / Fields sheet | No farm animation callbacks or surviving harvest particles while presented; capture residual GPU cost separately | Same |

The expansion envelope is a planning allowance for **12 visible planted plots in
the same environment**, with at most 54 concurrent harvest particles (six existing
nine-particle bursts). It is not an unlock feature, a saved layout, or a claim that
the existing island fits 12 plots. A later expansion issue must measure its actual
layout against this envelope before shipping. Do not add a 12-plot mode for #45.
Authored assets and effects share the whole-scene ceilings; their budgets are not
additive. Passing triangle or draw-call counts alone does not establish frame pacing.
Confirm provisional ceilings against captures; document any revision and rationale
in #45 instead of relaxing a limit silently.

## Repeatable capture procedure

1. Record commit SHA, dirty/clean state, app version/build, Xcode version, device
   model, OS version/build, refresh setting, orientation, locale, text size,
   VoiceOver/Reduce Motion settings, battery health/charge, thermal state, ambient
   temperature, brightness and power/network conditions in the result template.
   Use a dedicated test farm; preserve any existing player save. Use ordinary
   plant/harvest/sell actions to prepare states, without editing save dates or the
   system clock. The current crops take 20/45/90 seconds to grow.
2. Run `xcodegen generate`. In Xcode select the physical destination and local
   signing team, then select **Release** for the scheme's Profile action and use
   Product > Profile. Verify the recorded build configuration is Release with
   optimizations, without sanitizers, coverage or a debugger for timing captures.
   Keep local signing choices and generated projects out of Git. Repeat the final
   interaction check with the same Release app launched from its icon.
3. Cool the device to nominal thermal state before each repeat. Use fixed 50%
   brightness, auto-brightness and Low Power Mode off, and a recorded stable room
   temperature (target 20–24 °C). Keep screen orientation and refresh settings
   constant for comparisons. Capture every scenario below three times per device.
   Run landscape first and repeat gesture/selection checks in portrait. Label any
   interruption; repeat the affected run rather than discard unexplained hitches.
4. Capture launch separately: five first launches after device reboot and unlock,
   waiting for background startup activity to settle. Also record five process-cold
   relaunches separately; force-quitting alone does not establish a reboot-cold run.
   Use Instruments App Launch for process start to first app frame. Record a
   synchronized external video for icon tap to a fully drawn farm that responds to
   field selection, and report video frame resolution and timing uncertainty.
   A loading screen is not the interactive endpoint. Exclude install/download time.
5. Use Instruments Game Performance / Metal System Trace for presentation
   intervals and GPU work; Time Profiler for CPU work and hot stacks. Record the
   selected interval and actual refresh rate with p50/p95/p99, maximum and over-budget
   frame counts. Derive CPU frame work from the CPU timeline for each frame, not
   whole-process CPU percentage. Preserve trace locations and timestamp ranges.
   See Apple's [Metal performance workflow](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app).
6. In separate captures use Allocations/VM tracking for physical footprint and
   retained growth, and the Metal frame debugger for draws, submitted triangles,
   texture dimensions/formats/mipmaps and allocated bytes. Include shadow passes;
   do not infer GPU counts from Swift entity counts or source mesh counts. Capture
   a mature scene and an overlapping harvest burst. Frame-debugger captures pause
   execution and must not be used as timing samples. Measure the installed build's
   uncompressed .app bytes separately from an optional thinned download estimate.
7. Run a separate 30-minute unplugged session and equal-length screen-on idle
   control on the same device/settings, each three times from comparable charge
   and thermal conditions. Repeat crop/market loops, logging battery percentage
   every 5 minutes and thermal transitions. Record raw percentage-point losses,
   idle-adjusted loss and final-window pacing; coarse battery percentages are not
   a precise wattage measurement. Capture power/thermal data with the supported
   Instruments/device power tools, naming tool/version and unavailable counters.
   Use on-device recording disconnected from Xcode for sleep/wake verification:
   [Apple documents that pairing keeps Apple silicon awake](https://developer.apple.com/documentation/xcode/measuring-your-app-s-power-use-with-power-profiler).
8. Keep raw traces, videos, app bundles and device identifiers outside the repo.
   Attach sanitized evidence or stable artifact links to #45. Complete
   [the baseline record](PERFORMANCE_BASELINE.md), including failures. File a
   focused follow-up only for a reproducible, measured bottleneck, citing device,
   build, scenario, trace interval, exceeded budget and a retest criterion.

## Scenario checklist

| ID | Setup and interaction | Capture / verify |
| --- | --- | --- |
| E | Six empty plots; settle 30 s, record 60 s | Idle animation, footprint, frame pacing and launch endpoint |
| P | Six freshly planted plots; separate grain, rice and tomato runs | Capture from first planting through maturity; mark pre-ready intervals (grain grows too quickly for a 60 s steady window) |
| R | Six mature plots; each crop family separately; record 60 s | Ready markers, crop geometry, shadows; identify actual worst family |
| G | Repeat E and R; orbit continuously 20 s, pinch between limits 20 s, alternate gestures/reset/select 20 s | No sustained hitching, lost selection or accidental transaction; same sequence each repeat |
| H | Six ready plots; harvest consecutively as fast as normal controls allow; repeat 10 batches with ordinary regrowth/sales | Per-harvest intervals and actual burst overlap; nine particles per burst, 0.85 s lifetime in source; no claim of 54 observed unless captured |
| S | From R/H, open Market for 30 s, dismiss, open Fields for 30 s; repeat 20 cycles | Animation callbacks cease, particles clear, residual GPU cost and memory return measured for each sheet |
| B | From growing and from an active burst: Control Center/inactive 30 s, home/background 60 s, return; repeat 5 times | Callback/GPU stop after settling; no stale burst or animation catch-up; readiness reflects elapsed wall time and controls recover |
| M | Enable Reduce Motion before launch; repeat R/G/H/S/B; toggle during a burst | No sway, cloud/rotor motion, marker bounce or particles; readiness, camera and equivalent Fields actions still work |
| A | Repeat the crop-to-market loop with VoiceOver and accessibility text size; English and Portuguese | Controls remain usable and statuses readable; record existing localization gaps separately, without implementing #23/#27 |
| T | 30-minute loop through planting, gestures, harvest, sale and both sheets | Battery, thermal and last-window pacing against the same budgets |

For S/B, inspect both callbacks (`FarmSceneController.tick`) and the GPU timeline.
The source cancels `SceneEvents.Update`, but that alone proves neither suspension
of RealityKit rendering nor lower energy use. Crop text still has a SwiftUI periodic
timeline; classify its activity separately. Reduce Motion intentionally retains
growth updates, so zero CPU work is not the expected result for M.

## Dependency handoff

When physical measurements validate these budgets, add the budget and baseline
links to each dependent issue below. This table records the required handoff;
it does not claim those issues have already been updated or authorize their work.

| Issues | Required gate |
| --- | --- |
| [#44 assets](https://github.com/csambrosio01/fazendinha/issues/44), [#16 crops](https://github.com/csambrosio01/fazendinha/issues/16) | Whole-scene draws/triangles, texture allocation, Release size, launch and memory; compare one representative replacement before broad replacement |
| [#10 expansion](https://github.com/csambrosio01/fazendinha/issues/10), [#17 placement](https://github.com/csambrosio01/fazendinha/issues/17) | Projected envelope, actual maximum visible scene, camera extremes, all-ready state and retained memory |
| [#12 day/night](https://github.com/csambrosio01/fazendinha/issues/12), [#13 weather](https://github.com/csambrosio01/fazendinha/issues/13), [#25 feedback](https://github.com/csambrosio01/fazendinha/issues/25) | Combined GPU/effect cost, burst overlap, 30-minute thermal/battery run, inactive and Reduce Motion states |
