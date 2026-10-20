# Focused fixes

Prior routing receipt: code-quality-workflow / ST-A0 / 2026-08-16.

## Collection header
Structural decision: Local Fix. Execution decision: Local Fix Only.
Evidence: user screenshot and FlowContainer placing close immediately after subtitle.
Contract: right-aligned close inside full-width header, title/subtitle can wrap; existing browsing and close behavior preserved.
Files: collection_overlay.gd, header_overlay_test.*. Production budget: 20 changed lines.

## Battle header and status row
Structural decision: Local Fix. Execution decision: Local Fix Only.
Evidence: turn Label lacks vertical centering; desktop menu y=-4 vs currency y=0; independent status/turn budgets; HBox minimum width can prevent shrinking. Visual comparison also exposes 1100x720 health text extending beyond its bar into buffs; include number bounds and measured text width in regression.
Contract: shared vertical centers, exclusive status/turn/currency/menu regions; overflow via existing more popup; fixed board/papers and shield/health behavior preserved.
Files: battle_screen.gd, status_strip.gd, header_overlay_test.*. Production budget: 65 changed lines.

## Enemy animation
Structural decision: No Refactor. Execution decision: Local Fix Only (test fixture/config).
Evidence: local settings.cfg visual.reduced_motion=true. Guardian baseline 25 pass / 2 fail because test clicks during battle entrance lock, then later actions pass.
Contract: restore local normal motion per request; preserve reduced-motion option and all art/timelines. Await actual entrance completion before testing actions; test must not write player saves/settings.
Files: guardian_animation_test.gd, active_status_hud_test.gd and local settings.cfg (backup outside repo). Production animation scripts unchanged unless runtime evidence finds another fault. Active-status baseline also clicks its shield before entrance completes when normal motion is restored; await that existing input lock in the fixture.

Authorization: approved local fixes from current user complaint and ongoing UI repair request.
Baseline: header_overlay_test --before native captures; existing guardian native baseline log.
Verification: native header geometry/click checks at 8 desktop/landscape phone profiles including wide-to-narrow populated row, guardian actual attack/inject and rendered motion, existing HUD and responsive tests.
Forbidden: unrelated edits, fonts/art/colors, battle rules, APK/debug device changes, resets, dependency upgrades.
Rollback: compare/recover only current-task deltas from TEMP snapshots; preserve all pre-existing work.
Stop: new unrelated failures or production changes exceeding per-module budgets require new gate.
