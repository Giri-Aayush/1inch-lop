# 1inch Limit Order Protocol: Advanced Extensions

This repository extends the [1inch Limit Order Protocol](https://github.com/1inch) with advanced order execution strategies.

## ✨ Features

- ✅ **TWAP Order Execution** (Time-Weighted Average Price)
- 📈 Volatility-based logic (coming soon)
- ⚙️ Modular calculator contracts for flexible order computation

---

## 🧠 TWAPCalculator

TWAP (Time-Weighted Average Price) orders break a large order into smaller slices over time, to minimize slippage and market impact.

### 🔍 Logic Tested

| Test Name                    | Purpose                                                   |
|-----------------------------|------------------------------------------------------------|
| `testBasicTWAPCalculation`  | Validates proportional making amount in a basic scenario.  |
| `testTWAPWithRandomization` | Checks random execution logic using seeds.                 |
| `testTWAPExecutionExpired`  | Reverts if TWAP duration is over.                         |
| `testGetTWAPStatus`         | Confirms TWAP status: active flag, remaining intervals.    |
| `testInvalidTWAPData`       | Rejects invalid config like zero intervals.                |

---

## 📦 Installation

```bash
forge install
