[← Previous: The Promise](01-the-promise.md) · [Overview](../../README.md) · [Next: Immunization →](03-immunization.md)

# Chapter 2: Exact Matching

*A bond for every cheque.*

**Code:** [`r/matching.R`](../../r/matching.R), [`r/bonds.R`](../../r/bonds.R) · **Tests:** [`tests/test_matching.R`](../../tests/test_matching.R) (19), [`tests/test_bonds.R`](../../tests/test_bonds.R) (15) · **Excel:** `Matching` sheet

## The idea

The safest way to keep a promise is to own bonds that pay exactly the promised amount in every year. Then interest rates can do anything: the money arrives when the cheques are due, and the surplus never moves.

The shelf has a 4% annual-coupon government bond for every maturity from 1 to 30 years, and zero-coupon strips beyond that.

## Working backwards

A coupon bond with face $F_k$ maturing in year $k$ pays $F_k(1+r)$ in year $k$. Every bond maturing later also pays a coupon $r F_j$ in year $k$. So, starting from year 30 and working back to year 1,

$$F_k = \frac{L_k - r \sum_{j > k} F_j}{1 + r}$$

and the years 31 to 45 are covered by strips with face equal to the payment, $S_k = L_k$.

## Results

| Bond | Face |
|---|---|
| 1-year coupon bond | $47,929,639.92 |
| 10-year coupon bond | $51,882,082.98 |
| 20-year coupon bond | $42,057,008.99 |
| 30-year coupon bond | $17,642,424.71 |
| Year-31 strip | $15,330,938.56 |
| Year-45 strip | $61,001.41 |
| **Total coupon-bond face** | **$1,275,918,483.89** |

The bonds pay exactly the promise in all 45 years: the largest gap is a fraction of a cent. The portfolio costs exactly the PV of the promise, $1,174,851,028.89, and the tests check that this holds at 2%, 5% and 9% alike. Whatever rate you value at, the bonds and the promise are the same cash flows.

## The catch

Exact matching needs a bond for every single year, out to 45 years. Real markets rarely offer that. Long maturities are thin or missing, and buying 45 different bonds is expensive to trade. It also gives up any chance to earn more than the promise. The rest of the project asks how close you can get with only a few bonds.

In the game, exact matching is done with strips for every year. It is the benchmark that never fails.

## Checks

- Hand case: pay 100 at $t = 1$ and $t = 2$ with 10% coupon bonds: $F_2 = 90.9091$, $F_1 = 82.6446$.
- Every year's gap is zero, and the cost equals the PV at any rate.
- The Excel `Matching` sheet rebuilds the backward recursion in formulas.

## Key functions

| Function | What it does |
|---|---|
| `bond_cashflows()`, `bond_price()` | A bond's yearly cash flows and its price |
| `coupon_shelf()`, `strip_shelf()` | The shelves as tables |
| `dedicate_portfolio()` | The backward recursion |
| `dedication_cost()`, `dedication_table()` | Its cost, and the year-by-year table |
