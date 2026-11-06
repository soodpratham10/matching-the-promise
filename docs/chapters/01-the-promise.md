[← Overview](../../README.md) · [Next: Exact Matching →](02-exact-matching.md)

# Chapter 1: The Promise

*How heavy is the promise, and how much does it move when rates change?*

**Code:** [`r/promise.R`](../../r/promise.R) · **Tests:** [`tests/test_promise.R`](../../tests/test_promise.R) (29) · **Excel:** `Promise` sheet of [`excel/promise_crosscheck.xlsx`](../../excel/promise_crosscheck.xlsx) · **SQL:** [`sql/liability_profile.sql`](../../sql/liability_profile.sql)

## The block

Prairie Promise Annuities has 10,000 retirees, all aged 65. Each one is paid $10,000 at the end of every year while alive, up to age 110 at most. Survival follows a Gompertz-Makeham law with our own illustrative parameters:

$$\mu_x = A + B c^x, \qquad A = 0.0001, \quad B = 0.00002, \quad c = 1.10$$

so the chance a 65-year-old survives $t$ more years is

$${}_tp_{65} = \exp\left( -A t - \frac{B c^{65} (c^t - 1)}{\ln c} \right)$$

The expected payment in year $t$ is $L_t = 10{,}000 \times 10{,}000 \times {}_tp_{65}$. It starts at $98.97 million in year 1 and falls to $61,001 in year 45. On average each retiree receives 20.37 payments.

## Measuring the promise

With $v = 1/(1+i)$ and PV weights $w_t = L_t v^t / P$:

| Measure | Formula | Value at $i = 5\%$ |
|---|---|---|
| Present value | $P = \sum_t L_t v^t$ | **$1,174,851,028.89** |
| Macaulay duration | $D_{mac} = \sum_t t w_t$ | 9.8101 years |
| Modified duration | $D_{mod} = v D_{mac}$ | 9.3429 |
| Macaulay convexity | $C_{mac} = \sum_t t^2 w_t$ | 150.2832 |
| Modified convexity | $C_{mod} = v^2 \sum_t t(t+1) w_t$ | 145.2094 |

The promise behaves like a single payment due in about 9.8 years, even though payments run for 45.

## How good are the approximations?

If the rate rises from 5% to 6%, the exact PV falls to $1,073,075,449.67. Three approximations:

| Method | Formula | Estimate | Error |
|---|---|---|---|
| Macaulay | $P(i_0) \left( \frac{1+i_0}{1+i_1} \right)^{D_{mac}}$ | $1,070,530,346.69 | -0.237% |
| Modified (first order) | $P(i_0) (1 - \Delta i D_{mod})$ | $1,065,085,548.54 | -0.745% |
| With convexity (second order) | $P(i_0) \left( 1 - \Delta i D_{mod} + \tfrac{1}{2} \Delta i^2 C_{mod} \right)$ | $1,073,615,516.90 | +0.050% |

Adding convexity cuts the error by a factor of about 15. Convexity comes back in Chapter 3, where it decides whether a strategy is safe.

## Checks

- Hand case: 100 at $t=1$ and 200 at $t=2$, at 10%: $P = 256.1983$, $D_{mac} = 1.645161$, $C_{mac} = 2.935484$.
- A single payment has $D_{mac} = t$ and $C_{mac} = t^2$.
- With $B = 0$, survival reduces to $e^{-At}$.
- The SQL query recomputes $P$, $D_{mac}$ and $C_{mac}$ from the stored cash flows and agrees with R.
- The Excel `Promise` sheet rebuilds every column in formulas; the `Check` sheet shows the match to R.

## Key functions

| Function | What it does |
|---|---|
| `makeham_tpx(x, t)` | Survival probability under Gompertz-Makeham |
| `liability_cashflows()` | The block's expected payments, year by year |
| `pv_flat()`, `mac_duration()`, `mod_duration()`, `mac_convexity()`, `mod_convexity()` | The rate-sensitivity measures |
| `rate_profile()` | All of them in one row |
| `approx_pv()` | The three approximations above |
| `surplus_flat()` | Assets minus liabilities at a flat rate |
