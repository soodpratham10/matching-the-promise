[← Previous: Exact Matching](02-exact-matching.md) · [Overview](../../README.md) · [Next: Rate Storms →](04-rate-storms.md)

# Chapter 3: Immunization

*Two bonds that look right, and two that are right.*

**Code:** [`r/immunize.R`](../../r/immunize.R) · **Tests:** [`tests/test_immunize.R`](../../tests/test_immunize.R) (25) · **Excel:** `Immunization` sheet

## Redington's three conditions

At the current rate, surplus $S(i) = P_A(i) - P_L(i)$ is protected against small parallel shifts if

1. $P_A = P_L$: the bonds are worth the promise,
2. $D_A = D_L$: the durations match, so $S'(i) = 0$,
3. $C_A > C_L$: the bonds have more convexity, so $S''(i) > 0$ and $i$ is a local minimum of surplus.

## Two strips

To match PV and duration with strips at $m_1 < D_L < m_2$, split the PV:

$$P_2 = P_L \frac{D_L - m_1}{m_2 - m_1}, \qquad P_1 = P_L - P_2$$

then buy faces $P_1 (1+i)^{m_1}$ and $P_2 (1+i)^{m_2}$.

| | 5 and 20 years (bullet) | 2 and 30 years (barbell) |
|---|---|---|
| Cost of the short strip | $798,109,676.10 | $847,148,408.23 |
| Cost of the long strip | $376,741,352.78 | $327,702,620.66 |
| PV matches | ✓ | ✓ |
| Duration matches (9.8101) | ✓ | ✓ |
| Convexity vs the promise's 150.28 | **145.25 ✗** | **253.92 ✓** |
| Surplus if rates jump to 6% | **-$226,633.89** | +$4,758,662.57 |
| Surplus if rates drop to 4% | **-$321,874.09** | +$6,438,622.91 |

The bullet is the trap. It matches the PV and the duration exactly, but the promise is more spread out than two strips at 5 and 20 years. So the promise has more convexity, and the bullet **loses money whichever way rates move**. Matching the duration is not enough.

## Full immunization

Full immunization protects against parallel shifts of *any* size. Every payment $L_t$ is split between the shelf strips just before ($a$ years earlier) and just after ($b$ years later):

$$F_{before} = \frac{b}{a+b} L_t v^a, \qquad F_{after} = \frac{a}{a+b} L_t (1+i)^b$$

A payment that falls on a shelf maturity is matched directly. The shelf has strips at 1, 2, 3, 5, 7, 10, 15, 20, 25, 30, 40 and 50 years.

| Strip | Cost ($M) |
|---|---|
| 1 | 94.25 |
| 2 | 88.75 |
| 3 | 122.67 |
| 5 | 147.19 |
| 7 | 157.60 |
| 10 | 198.85 |
| 15 | 174.63 |
| 20 | 105.76 |
| 25 | 55.02 |
| 30 | 25.79 |
| 40 | 4.31 |
| 50 | 0.04 |

The result passes all three Redington conditions. Surplus is $94,318 at 6%, $132,575 at 4%, $620,377 at 8% and $1,730,704 at 2%. The tests check it never goes negative for any flat rate from 0.1% to 15%.

## Checks

- Hand case: a liability of 100 at $t = 3$ with strips at 1 and 5, at 0%: costs 50 and 50, asset convexity 13 against 9.
- Hand case: 100 at $t = 4$ between strips at 2 and 5, at 0%: faces 33.33 and 66.67.
- The Excel `Immunization` sheet rebuilds both pairs and the full bracketing in formulas.

## Key functions

| Function | What it does |
|---|---|
| `redington_pair()` | Two strips matching PV and duration |
| `redington_check()` | The three conditions |
| `full_immunization()` | Bracketing every payment |
| `surplus_curve()` | Surplus across flat rates, for the plot |
