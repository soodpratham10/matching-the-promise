[← Overview](../README.md)

# The game: The Rate Storm

**[▶ Play it](https://soodpratham10.shinyapps.io/matching-the-promise/)**

## Your job

You are the investment actuary of **Prairie Promise Annuities**, a closed block of 10,000 retirees aged 65, each paid $10,000 a year for life. The promise is worth **$1,174.9M** at 5%, with a duration of **9.81 years**.

Your budget is **$1,233.6M**: the value of the promise plus 5% capital ($58.7M).

## The shelf

You buy government zero-coupon strips with 2, 5, 10, 20, 30 and 50 years to maturity, in steps of 5% of the budget. Anything you don't spend stays in cash and earns the one-year rate each year. While you adjust the sliders, the sidebar shows your bonds' value, duration and convexity against the promise's, with a live Redington check.

The default portfolio (20% in 5-year, 50% in 10-year, 20% in 20-year and 10% in 30-year strips) has a duration of 13.0 years: too long. See what a rate spike does to it.

## The storms

| Storm | What happens to the curve |
|---|---|
| Calm seas | Flat at 5% for 20 years |
| Rate crash | Falls 0.5% a year for five years, to 2.5% |
| Rate spike | Rises 0.5% a year for six years, to 8% |
| Steepener | The slope rises 0.4% a year for five years, to +2%; the 10-year rate stays at 5% |
| Inversion | Level up 1% in two years; the slope falls to -2% |
| Random storm | Level: $\ell_y = 0.9 \ell_{y-1} + \varepsilon$, sd 0.75%. Slope: $s_y = 0.8 s_{y-1} + \eta$, sd 0.4%. The game number is the seed |

The spot rate for $m$ years is $5\% + \ell + s (m - 10)/10$, floored at 0.25%.

## Each year

1. Cash grows at last year's one-year rate.
2. Strips maturing this year are added to cash.
3. The year's expected payments to retirees go out of cash. Cash can go negative, which means borrowing at the one-year rate.
4. The remaining strips and the remaining promise are valued on this year's curve.
5. **Surplus** = cash + value of strips − value of the promise.

## The meter and the score

| Status | Rule |
|---|---|
| 🟢 Safe | Surplus at least 60% of the starting capital |
| 🟡 Drifting | Surplus between 0 and 60% of the starting capital |
| 🔴 Underwater | Surplus below zero: the fund owns less than the promise is worth |

**Score** = the worst surplus over the 20 years ÷ the starting capital.

| Grade | Score | Title |
|---|---|---|
| A | 90% or more | Grandmaster of Matching |
| B | 60% to 90% | Steady Hand |
| C | 25% to 60% | Lucky Survivor |
| D | 0 to 25% | Running on Fumes |
| F | below 0 | Sunk by the Storm |

**Storm Survivor** 🏆: never underwater during the storm (calm seas doesn't count).

## The Yield Curve Gazette

A headline appears in any year when the 10-year rate moves by 25 basis points or more, when the fund goes underwater or comes back up, or when it drifts off its match.

## The comparison

Under the same storm, the results screen runs the five textbook strategies next to yours:

| Strategy | Bonds |
|---|---|
| Cash-flow matched | A strip for every year's payment |
| Redington barbell | Strips at 2 and 30 years, matching PV and duration |
| Full immunization | Every payment bracketed by the shelf strips around it |
| All cash | No bonds |
| All in 30-year strips | One strip, duration 30 |

All of them spend the same budget, so all start with the same $58.7M surplus.

## Tuning

Every number was checked in an independent Python run before shipping:

| Storm | Cash-flow matched | Redington | Full | All cash | All 30-year |
|---|---|---|---|---|---|
| Calm seas | A | A | A | A | A |
| Rate crash | A | A | A | F | A |
| Rate spike | A | A | A | A | F |
| Steepener | A | F | A | F | F |
| Inversion | A | A | A | A | F |
| 300 random storms, share underwater | 0% | 43% | 0% | 61% | 92% |

The lesson the game is built around: the barbell passes every Redington condition at the start, but with no rebalancing it drifts, and twists find it.

## Limitations

- Mortality is deterministic: payments are the expected amounts, with no longevity surprises.
- Bonds are default-free government strips with no transaction costs.
- No rebalancing during the 20 years: strategies are bought once and held.
- The curve has only two moving parts (level and slope).
- All assumptions are illustrative and not calibrated to real data.
