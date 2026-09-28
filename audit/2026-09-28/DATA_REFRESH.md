# NCD Dashboard data refresh — 2026-09-28

## Production data
- `static/ncd_indicator_summary.csv`
  - Existing indicators 1–12 and 16–18 preserved.
  - Indicators 13–15 replaced with verified annual + quarterly outputs from the 2026-09-28 query run.
- `static/foot_risk_summary.csv`
  - Replaced with verified annual + quarterly foot-risk summaries from the same run.

## Source files used
- Quarter indicators: uploaded `003(5).csv`
- Annual indicators: uploaded `004(3).csv`
- Annual foot risk: uploaded `005(4).csv`
- Quarter foot risk: uploaded `008(1).csv`

## Audit evidence retained
- `year_reconciliation.csv` (uploaded `006(3).csv`)
- `year_join_audit.csv` (uploaded `007(2).csv`)
- `quarter_reconciliation.csv` (uploaded `009(2).csv`)
- `quarter_join_audit.csv` (uploaded `010(2).csv`)
- Annual and quarter JOIN-audit SQL scripts.
- Pre-refresh production CSV snapshots for rollback/comparison.

## Validation summary
- Indicator keys are unique for period/year/order/indicator.
- Foot-risk keys are unique for period/year/order/risk code.
- All foot-risk periods contain all 4 risk codes (Z0280–Z0283).
- Published percentages match numerator/denominator to 2 decimal places.
- Indicator 15 numerator reconciles exactly to the sum of foot-risk HN for every annual and quarterly period in FY2566–FY2569.

## Visual design
No visual/theme files were changed in this refresh. The existing mint/emerald dashboard palette and the eye/oral/foot domain colors are preserved.
