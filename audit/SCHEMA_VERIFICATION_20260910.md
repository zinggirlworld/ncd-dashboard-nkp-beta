# SSB Schema Verification — Foot Risk Dashboard

Source: `SSB-SCHEMA(5).zip` supplied with this review.

## Verified source contract

| Object       | Columns used                                  | Verified metadata                             |
| ------------ | --------------------------------------------- | --------------------------------------------- |
| `dbo.VNMST`  | `VISITDATE`, `VN`, `HN`                       | datetime, varchar(20), varchar(20)            |
| `dbo.VNPRES` | `VISITDATE`, `VN`, `CLINIC`, `CLOSEVISITTYPE` | datetime, varchar(20), varchar(8), varchar(6) |
| `dbo.VNDIAG` | `VISITDATE`, `VN`, `ICDCODE`                  | datetime, varchar(20), varchar(14)            |

Verified relations in codebook:

- `VNPRES(VISITDATE + VN) -> VNMST(VISITDATE + VN)`
- `VNDIAG(VISITDATE + VN) -> VNMST(VISITDATE + VN)`

Clinic codebook:

- `0105`: คลินิกโรคเบาหวาน (DM)
- `1201`: กายภาพบำบัดในเวลา

Therefore `1201 + Z0280-Z0283` must remain explicitly classified as a legacy/business rule pending owner confirmation; it is not inferred from schema metadata alone.
