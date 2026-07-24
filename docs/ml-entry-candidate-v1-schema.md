# Kontrak Dataset `ts7_entry_candidate_v1`

## Status dan tujuan

Schema ini adalah output resmi logger observation-only Fase 1. Satu run menghasilkan snapshot
candidate original entry, eksekusi order aktual, hasil original trade, hasil recovery cycle, dan
label price-path 40/50 candle. Logger tidak memberi izin atau veto entry.

Output disimpan melalui `FILE_COMMON`, di luar repository:

~~~text
<MetaTrader Terminal Common Files>/<InpMlDatasetDirectory>/<RunId>/
  candidate_setups.csv
  trade_entries.csv
  trade_outcomes.csv
  cycle_outcomes.csv
  barrier_outcomes.csv
  run_manifest.json
~~~

Default `InpMlDatasetDirectory` adalah `TS7_ML`. Raw CSV, manifest aktual, journal, report tester,
dan file `.ex5` tidak boleh di-commit.

## Identitas dan relasi

- `RunId` harus unik untuk setiap eksekusi tester/forward.
- Logger menolak start jika `run_manifest.json` untuk `RunId` yang sama sudah ada; file lama tidak
  ditimpa.
- `SetupId` deterministik dari strategy version, symbol, M1, arah, signal epoch, dan candidate-bar
  epoch.
- `CycleId` adalah `SetupId` ditambah suffix `_CYCLE`.
- `SetupId` menghubungkan seluruh file.
- `CycleId` hanya tersedia bila order original berhasil.
- Satu `SetupId` memiliki tepat satu candidate serta dua barrier record, yaitu horizon 40 dan 50.
- Original `PositionId` menghubungkan entry dan trade outcome. Posisi recovery dipasangkan ke
  cycle secara internal dan financial-nya dijumlahkan ketika cycle selesai.

## Nilai kosong dan tipe

- Missing value ditulis literal `NA`; angka nol tidak dipakai sebagai pengganti missing data.
- Boolean ditulis `true` atau `false`.
- Waktu ditulis dalam broker/tester time: `YYYY.MM.DD HH:MM:SS`.
- Harga memakai digits symbol; uang memakai dua decimal; normalized feature memakai decimal.
- `Direction` adalah `1` untuk BUY dan `-1` untuk SELL.
- Consumer wajib memeriksa `SchemaVersion`, manifest, jumlah kolom, duplicate key, dan pairing
  sebelum training.

## `candidate_setups.csv`

Primary key: `(RunId, SetupId)`.

~~~text
SchemaVersion,RunId,SetupId,StrategyVersion,SourceRevision,PresetHash,
Symbol,Timeframe,CandidateTime,CandidateBarTime,SignalTime,Direction,
CciSignalType,SignalAgeBars,CandidatePrice,Bid,Ask,SpreadPoints,
SpreadATR,BarrierATR,ATR_M5,ATRRatioM1M5,InitialSL,InitialSLPoints,
InitialSLATR,FeatureReady,CciSignal,CiSignal,CciCandidate,CiCandidate,
CciDeltaDir,CciGapSignalDir,CciGapCandidateDir,HiLoSignalAlign,
PsarSignalAlign,STSignalAlign,STMTFSignalAlign,ConfirmationsAtSignal,
LateConfirmMask,HiLoLatencyBars,PsarLatencyBars,STLatencyBars,
STMTFLatencyNativeBars,STMTFLatencySeconds,HiLoAgeBars,PsarAgeBars,
STAgeBars,STMTFAgeBars,Return1ATR,Return3ATR,Return5ATR,Return10ATR,
Return20ATR,BodyATR,RangeATR,UpperWickATR,LowerWickATR,
DisplacementATR,PreEntryMFEATR,PreEntryMAEATR,DistanceEMAATR,
EMASlope5ATR,EMASlope10ATR,RecentRangePositionDir,TickVolume,Hour,
Minute,DayOfWeek,TimeOfDaySin,TimeOfDayCos,DayOfWeekSin,
DayOfWeekCos,AsiaSession,LondonSession,NewYorkSession,
SessionDistanceReady,MinutesFromSessionOpen,MinutesToSessionClose,
StructureReady,DirectionalRoomATR,DataIntegrityFlag
~~~

Kelompok field:

| Kelompok | Definisi |
| --- | --- |
| Provenance | schema/run/setup/strategy/source revision/preset hash dan data-integrity flag |
| Candidate | waktu signal/candidate, arah, reference Bid/Ask, spread, dan initial SL aktual |
| CCI | tipe signal, umur signal, raw CCI/CI saat signal dan candidate, delta direction-normalized |
| Confirmation | alignment pada signal, mask, latency, dan umur state HiLo/PSAR/ST M1/ST M5 |
| Price action | return, candle anatomy, displacement, dan pre-entry excursion dalam ATR |
| Regime | ATR M1/M5, EMA distance/slope, range position, volume, dan directional S/R room |
| Waktu | broker time mentah, cyclical encoding, session flag, dan jarak boundary session aktif |

`FeatureReady=false` berarti satu atau lebih feature wajib gagal dibaca. Record tetap disimpan untuk
audit, tetapi tidak boleh langsung masuk training. `StructureReady` dan `SessionDistanceReady`
adalah readiness terpisah karena keduanya dapat validly unavailable.

Direction normalization membuat nilai positif berarti mendukung arah candidate. Candle dan ATR
selalu menggunakan data tertutup; candidate price dan spread menggunakan tick keputusan.

## `trade_entries.csv`

Primary key: `(RunId, SetupId, AttemptNumber)`.

~~~text
SchemaVersion,RunId,SetupId,AttemptNumber,CycleId,OrderTicket,DealTicket,PositionId,
RequestTime,ActualTime,Direction,RequestedPrice,ActualPrice,Volume,
InitialSL,InitialSLPoints,TakeProfit,SpreadPoints,Retcode,
RetcodeDescription,OrderSucceeded
~~~

File ini menyimpan setiap order attempt. Retry untuk candidate yang sama menaikkan
`AttemptNumber` tanpa menduplikasi snapshot candidate atau barrier tracker. Candidate yang seluruh
attempt-nya gagal tetap memiliki barrier outcome, tetapi tidak memiliki trade/cycle outcome aktual.

## `trade_outcomes.csv`

Primary key: `(RunId, SetupId)`.

~~~text
SchemaVersion,RunId,SetupId,CycleId,PositionId,ExitDeal,ExitTime,
Direction,ExitPrice,ExitReason,GrossProfit,Commission,Swap,NetProfit,
BarsHeld,MFEPoints,MAEPoints,RecoveryEligible
~~~

Financial original trade dijumlahkan dari seluruh deal pada `PositionId`, sehingga entry/exit
commission dan swap tidak hilang. `RecoveryEligible=true` menandai original loss yang dapat
memulai recovery; ini bukan bukti bahwa recovery benar-benar dimulai.

## `cycle_outcomes.csv`

Primary key: `(RunId, SetupId)`.

~~~text
SchemaVersion,RunId,SetupId,CycleId,OutcomeTime,BusinessOutcome,
OriginalNetProfit,RecoveryNetProfit,CycleNetProfit,RecoveryStarted,
RecoveryEntries,MaxRecoveryLevel,CompletionReason
~~~

`CycleNetProfit = OriginalNetProfit + RecoveryNetProfit`. Recovery financial dijumlahkan dari
seluruh deal semua `PositionId` recovery yang terkait. Label:

- `NO_RECOVERY`;
- `RECOVERY_L1_L3`;
- `RECOVERY_L4_PLUS`;
- `INCOMPLETE`.

`RecoveryEntries` dan `MaxRecoveryLevel` berasal dari posisi yang benar-benar dieksekusi, bukan
order attempt. `CompletionReason` menjelaskan reset seperti `TARGET_REACHED`,
`CLASSIC_TARGET_REACHED`, `MAX_DRAWDOWN`, atau alasan lifecycle lain.

## `barrier_outcomes.csv`

Primary key: `(RunId, SetupId, HorizonBars)`.

~~~text
SchemaVersion,RunId,SetupId,HorizonBars,OutcomeTime,BarrierOutcome,
Direction,ReferencePrice,ATRPrice,FavorablePrice,AdversePrice,
ElapsedBars
~~~

Terdapat horizon `40` dan `50`. Barrier simetris memakai `1.0 × ATR RMA(14) M1` dari candle
tertutup terakhir. BUY memakai Ask sebagai reference dan Bid untuk touch; SELL memakai Bid sebagai
reference dan Ask untuk touch.

Nilai `BarrierOutcome`:

- `FAVORABLE_FIRST`;
- `ADVERSE_FIRST`;
- `UNRESOLVED`;
- `AMBIGUOUS`;
- `LABEL_DATA_ERROR`;
- `HORIZON_INCOMPLETE` bila tester/EA berhenti sebelum horizon selesai.

Hanya `FAVORABLE_FIRST` dan `ADVERSE_FIRST` masuk binary training awal.

## `run_manifest.json`

Manifest memuat:

- schema dan run ID;
- strategy version;
- source revision;
- SHA-256 preset;
- symbol/timeframe;
- definisi ATR dan horizon;
- data-integrity flag;
- build time;
- status tester/optimization.

Run retained wajib mengisi `InpMlSourceRevision` dengan commit/tag build dan menggunakan
`InpMlPresetHash` yang cocok dengan preset aktual. Manifest kosong atau mismatch membuat run gagal
audit.

## Pemeriksaan minimum sebelum Fase 2

1. Seluruh CSV dapat dibaca dan jumlah kolom setiap row sama dengan header.
2. Candidate `SetupId` unik dan setiap candidate memiliki barrier 40/50 unik.
3. Entry sukses memiliki tepat satu trade outcome dan satu cycle outcome.
4. Tidak ada `FeatureReady=false`, ATR tidak valid, atau `LABEL_DATA_ERROR` tanpa investigasi.
5. Jumlah `CycleNetProfit` sama dengan perubahan balance tester, dengan toleransi rounding.
6. Logger OFF dan ON menghasilkan urutan deal, final balance, dan summary original yang identik.
7. Run duplikat pada period/tick yang sama tidak dihitung sebagai observasi independen.
