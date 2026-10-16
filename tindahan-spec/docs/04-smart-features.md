# 04 — Smart Features (all on-device, no internet)

All logic is pure Dart in `lib/domain/` with unit tests. No external AI services.

---
## 1. Barcode scanning
- Package: `mobile_scanner` (ML Kit on Android, works offline). Permission: `CAMERA` only.
- Opens as a bottom sheet from Sell, Products, and the restock flow.
- Features: flashlight toggle, manual barcode entry fallback, vibrate on success, ignore repeat reads for 1.5 seconds.
- Returns the raw barcode string to the caller; the caller decides what to do (see `03-business-rules.md`).
- Handle: permission denied (explain and fall back to manual entry), no camera, poor lighting hint.

---
## 2. Voice input
- Package: `speech_to_text`. Permission: `RECORD_AUDIO` only.
- Prefer on-device recognition. Check locale availability (`fil-PH`, `en-PH`, `en-US`). If the offline pack is missing, show a sheet explaining how to download it (Settings → Google → Voice) and fall back to typing.
- Mic UI: pulsing button while listening, live transcript, auto-stop after ~2 s silence, "Didn't catch that" retry state.

### Supported commands
| Intent | Examples |
|---|---|
| RESTOCK | "Add 10 Coke Mismo", "Dagdag sampung Piattos" |
| RESTOCK (multi) | "Sampung Coke, lima Piattos, dalawang kape" |
| NEW_PRODUCT | "Bagong produkto Lucky Me Pancit Canton presyo 12 stock 20" |
| SEARCH | "Hanap Safeguard" |

### `VoiceCommandParser` (pure Dart)
Input: transcript string + list of known product names. Output: `VoiceResult { intent, items: [ {rawText, matches: [ {product, score} ], qty, price?, stock?} ] }`.

Pipeline:
1. **Normalize:** lowercase, trim, remove punctuation, collapse spaces.
2. **Numbers → digits.** English (one…ninety, hundred) and Tagalog: isa=1, dalawa=2, tatlo=3, apat=4, lima=5, anim=6, pito=7, walo=8, siyam=9, sampu=10, labing-isa=11, labindalawa=12, labintatlo=13, labing-apat=14, labinlima=15, dalawampu=20, tatlumpu=30, apatnapu=40, limampu=50, isang daan=100, dosena=12. Linkers "ng/na" ("dalawang") strip to the base word. Digits already in the text are kept.
3. **Intent keywords:** dagdag/add/restock/dagdagan → RESTOCK; bago/bagong/new → NEW_PRODUCT; hanap/search/find → SEARCH. No keyword + "number + name" pattern → RESTOCK.
4. **Split multiple items** on commas, "at", "and", "tapos".
5. **Extract** `qty` (number before the name), `presyo/price` and `stock` values for NEW_PRODUCT.
6. **Fuzzy match** the remaining name text to product names: normalized Levenshtein similarity plus token overlap. Return the top 3 with scores. Auto-select only when top score ≥ 0.80 and ahead of the second by ≥ 0.10; otherwise the UI asks the owner to pick.
7. **UI shows a confirmation card** with editable rows. Nothing saves until the owner taps Confirm.

Tests: at least 20 phrases including Taglish, mistakes ("pyatos"), multi-item commands, and no-match cases.

---
## 3. Utang risk score (headline innovation)
Explainable, rule-based score (0–100, higher = riskier) computed per customer by `RiskScorer`. Optional future upgrade: K-Means clustering on the same features, but ship the rule-based version first because the owner can understand the reasons.

### Features (from `utang_entries`)
- `late_ratio` = overdue-at-payment charges ÷ total charges (a charge paid after its due date, or still unpaid and overdue, counts as late)
- `utilization` = current balance ÷ credit limit (if no limit: balance ÷ owner's default limit setting, default ₱500)
- `oldest_unpaid_days` = age of the oldest unpaid charge
- `payment_gap_days` = days since the last payment (or since the first charge if none)
- `history_count` = number of charges

### Formula
```
score = 100 * (
    0.35 * late_ratio
  + 0.25 * min(utilization, 1)
  + 0.25 * min(oldest_unpaid_days / 30, 1)
  + 0.15 * min(payment_gap_days / 30, 1)
)
```
- Levels: **Low** < 30, **Medium** 30–59, **High** ≥ 60.
- Customers with `history_count < 3` show "New" (unrated) instead of a level.
- Always return reasons, e.g. "2 of 4 charges paid late", "₱320 unpaid for 24 days". Show them on the customer detail screen.

### Use in the UI
- Color chips on the Utang list (Low=green, Medium=amber, High=red, New=gray).
- Before charging a sale to utang: Medium → soft warning, High → strong warning with the reasons; the owner can still proceed.
- Suggested credit limit: Low = current limit +20% (or default), Medium = hold, High = reduce to current balance.
- Recompute after each charge/payment and once on app start. Cache in `customers.risk_score` and `risk_level`.

---
## 4. Smart restock suggestions
Computed by `RestockAdvisor` from `stock_movements` (type = sale) over the last 14 days.

```
avg_daily  = weighted moving average of daily units sold (recent days weigh more, e.g. weights 1..14)
days_left  = stock_qty / avg_daily        (if avg_daily = 0 → no suggestion)
target     = ceil(avg_daily * target_days * boost)   // target_days default 7
suggest    = max(0, target + safety - stock_qty)     // safety default = low_stock_level
boost      = 1.2 if the next 2 days include the 15th or 30th (payday) or a weekend, else 1.0
```
- Show only items where `days_left <= 3` or `stock_qty <= low_stock_level`, sorted by urgency (lowest `days_left` first).
- Each row: product, stock, avg/day, days left, suggested qty, and a one-tap "Restock" button (opens the restock dialog prefilled).
- Need ≥ 5 days of history for a product; otherwise fall back to the simple low-stock rule.
- Output also as a shareable shopping list (plain text) for the palengke trip.
- Tests: zero sales, a spike day, new product with little history, payday boost.

---
## 5. Expiry tracking (supporting)
- Optional `expiry_date` per product. Home shows "Expiring soon" for items expiring within 14 days (setting).
- Expired items can be written off with one tap (logs `expired` and removes stock).
