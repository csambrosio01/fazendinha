# Economy baseline

Issue #21 records the current prototype economy before roadmap #52 adds seed
inventory (#9), unlocks (#14), upgrades (#19), or expanded content. These are
design targets and deterministic regression checks, not evidence from playtests.
The baseline requires no network access and changes no version-1 save fields.

## Crop balance

The farm starts with 50 coins, six empty reusable plots, and no produce. Planting
charges coins directly; one harvest yields one item. `SeedType` owns costs, growth
times, and sale prices; `GameStore.harvest` applies the yield.

| Crop | Plant cost | Growth | Yield | Sale price | Net per harvest | Net per plot/minute | Six-plot cost / net |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Grain | 3 | 20 s | 1 | 7 | 4 | 12 | 18 / 24 |
| Rice | 5 | 45 s | 1 | 12 | 7 | 9⅓ | 30 / 42 |
| Tomato | 8 | 90 s | 1 | 20 | 12 | 8 | 48 / 72 |

Net profit divided by planting cost is 4/3, 7/5, and 3/2 respectively.
Grain rewards frequent attention with the highest earning rate. Tomato rewards
longer gaps with the highest profit per completed harvest and per coin invested;
rice sits between them. All three can fill the starting farm, return a profit,
and fund another full planting. The fastest earning rate is 1.5 times the slowest.

## Session assumptions and targets

Target a first plant–harvest–sell loop in 20–90 seconds, observable progress in a
five-minute active session, and a useful harvest after a five-to-ten-minute gap.
These short timers are intentional prototype values, not a final retention model.

The [economy tests](../FazendinhaTests/GameEconomyTests.swift) run actual `GameStore`
actions with injected fixed time and an in-memory repository. Each strategy
plants all six plots with one crop, then harvests and sells the complete batch.
Actions have zero tap/save latency. Growth is ready at the exact stored deadline.
Active play repeats at every deadline; returning play collects once at the end
of the session. Active play does not replant when the next complete cycle would
exceed the measurement horizon. Balances below are
cash after sale, with empty plots and inventory, so planted assets do not obscure
the comparison. Actual human sessions will usually complete fewer cycles.

| Strategy and elapsed time | Grain coins | Rice coins | Tomato coins |
| --- | ---: | ---: | ---: |
| Active, 5 minutes | 410 | 302 | 266 |
| Active, 10 minutes | 770 | 596 | 482 |
| Return at 5 minutes, one harvest | 74 | 92 | 122 |
| First return at 10 minutes, one harvest | 74 | 92 | 122 |

Active five-minute cycle counts are 15/6/3; ten-minute counts are 30/13/6.
Time away never repeats harvests automatically: returning after a day still
produces only one item per planted plot.

| Active cash milestone, measured after sale | Grain | Rice | Tomato |
| --- | ---: | ---: | ---: |
| First balance of at least 100 coins | 60 s | 90 s | 90 s |
| First balance of at least 200 coins | 140 s | 180 s | 270 s |

These milestones measure savings only. There are no upgrades or other purchases
beyond planting yet. Upgrade affordability remains deferred to #19; its actual
prices and rules must extend this baseline without inventing an upgrade here.

## Low-coin recovery

From a new farm, planting six tomatoes leaves two coins but six growing assets.
At 90 seconds, harvesting and selling the batch raises cash to 122 coins.
Zero cash is also reachable: plant five tomatoes and one rice (five coins left),
harvest the rice at 45 seconds, then replant rice (zero coins). Selling the stored
rice restores 12 coins while all six plots remain planted. Recovery uses existing
actions and requires neither a free seed nor a rescue payment.

For a valid new farm under the current local rules, define eventual sale value
as coins plus stored produce value plus the sale value of planted crops. Planting
increases this value by the crop profit; harvest and sale preserve it. It starts
at 50 and cannot fall. Therefore a reachable balance below the cheapest seed cost
must still have produce or a crop that can eventually be sold. This argument
assumes successful legal transactions, eventual clock progress, and no external
save edits; it does not promise recovery for arbitrary malformed imported state.

## Reviewing future balance changes

Keep explicit numeric regression expectations, including costs, exact readiness,
yield, prices, session results, and recovery. Review earning rates and return on
cost together to catch disproportionate rewards and preserve both active and
returning tradeoffs. Recalculate this document and simulation expectations when
an intentional balance change lands; explain the changed target in its issue.
New spending, destruction, or expiry rules must revisit the recovery argument.
Run `make test` and run `make ci-local` before opening the pull request. Keep
simulation helpers in tests and game rules independent from SwiftUI/RealityKit.
