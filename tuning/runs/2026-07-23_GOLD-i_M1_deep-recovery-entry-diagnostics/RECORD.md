# Deep-Recovery Entry Diagnostics — Folder 21

## Tujuan

Mencari konteks entry yang membedakan original winner, recovery dangkal L1–L3, dan 53 recovery
L4+ pada candidate offset 50. Run ini observation-only dan tidak menambahkan filter entry.

## Control

Gunakan seluruh konfigurasi folder 20:

- symbol `GOLD.i#`, timeframe `M1`;
- periode 2026-01-04 sampai 2026-05-02;
- CCI validity 3 dan CCI signal mode BOTH;
- ADX filter false;
- trailing start/step/distance 500;
- `InpTrailingBreakEvenOffsetPoints=50`;
- diagnostics true;
- seluruh session, indicator, lot, dan recovery setting sama.

Input diagnostics baru:

~~~text
InpOriginalDiagEmaPeriod=50
~~~

Simpan hasil sebagai folder `21`.

## Feature definitions

Seluruh nilai berikut dibagi ATR diagnostics dan disesuaikan terhadap arah posisi. Positif berarti
searah posisi; negatif berarti melawan posisi.

| Field | Definition |
| --- | --- |
| `Impulse3ATR` | BUY: `(Close[1]-Close[4])/ATR`; SELL dibalik |
| `Impulse5ATR` | BUY: `(Close[1]-Close[6])/ATR`; SELL dibalik |
| `DistanceEMAATR` | BUY: `(Entry-EMA50)/ATR`; SELL dibalik |
| `SignalDriftATR` | BUY: `(Entry-SignalClose)/ATR`; SELL dibalik |
| `ContextReady` | Seluruh source feature tersedia dan valid |

## Acceptance check

Karena hanya menambah telemetry, folder 21 harus mereproduksi folder 20:

| Metric | Folder 20 control | Folder 21 |
| --- | ---: | ---: |
| Original closed | 594 | Pending |
| Winner / loser / neutral | 282 / 312 / 0 | Pending |
| Original win rate | 47.47% | Pending |
| Recovery entry rate | 52.53% | Pending |
| Recovery L4+ absolute | 53 | Pending |
| Total trades / deals | 1,343 / 2,686 | Pending |
| Total net profit | $3,427.74 | Pending |
| Profit factor | 1.52 | Pending |
| Relative equity DD | 31.88% | Pending |
| Active weekdays | 84/85 | Pending |
| Data errors / context errors | 0 / 0 | Pending |
| Active records remaining | 0 | Pending |

Jika trading history berubah, jangan gunakan feature untuk memilih filter.

## Analysis groups

Setelah run diterima, bandingkan distribusi setiap feature untuk:

1. 282 original winner;
2. 259 recovery L1–L3;
3. 53 recovery L4+.

Catat median, quartile, sample size, dan overlap. Sebuah threshold hanya menjadi kandidat test bila
menolak bagian material kelompok L4+ dengan false rejection winner yang rendah. Screening awal:
menolak minimal 20% L4+ dengan maksimal 10% winner. Threshold tersebut tetap harus diuji melalui
full Strategy Tester karena penolakan entry mengubah urutan trade.

## Status

Pending backtest folder 21. Raw journal tidak boleh di-commit.
