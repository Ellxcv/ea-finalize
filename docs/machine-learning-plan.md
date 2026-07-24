# Spesifikasi Machine Learning Entry Original TESTING_STRAT_7

## Status

- Fase 0: selesai dan disetujui pada 2026-07-24.
- Baseline strategi: `folder32_v1`.
- Schema dataset awal: `ts7_entry_candidate_v1`.
- Scope model pertama: meta-filter/veto entry original.
- Perilaku trading: belum berubah; implementasi source dimulai pada Fase 1.

Dokumen ini adalah spesifikasi normatif. Handoff
[ea-ml-roadmap-context.md](ea-ml-roadmap-context.md) menjadi sumber konteks, tetapi tidak
menggantikan keputusan yang dikunci di sini.

## 1. Tujuan dan batas scope

Model pertama menjawab:

> Ketika seluruh aturan legacy sudah menyatakan original entry valid, apakah candidate ini layak
> diambil atau sebaiknya ditolak?

ML hanya menjadi filter tambahan. ML tidak boleh:

- menghasilkan arah BUY/SELL sendiri;
- membuka setup di luar aturan original;
- mengubah CCI, HiLo, PSAR, SuperTrend, session, SL, trailing, atau recovery;
- menentukan lot atau compound;
- mengelola posisi recovery;
- memakai candle berjalan bila training memakai candle tertutup.

Mode runtime yang direncanakan:

| Mode | Perilaku |
| --- | --- |
| `ML_OFF` | Perilaku harus identik dengan `folder32_v1` |
| `ML_SHADOW` | Menghitung dan mencatat score tanpa memblokir entry |
| `ML_FILTER` | Mengizinkan atau menolak candidate berdasarkan model dan threshold beku |

Default tetap `ML_OFF`. Jika `ML_FILTER` aktif dan model/schema/inference tidak valid, original
entry baru diblokir secara fail-closed. Posisi terbuka, trailing, daily protection, dan recovery
yang sedang aktif harus tetap dikelola.

## 2. Keputusan Fase 0 yang dikunci

| Area | Keputusan |
| --- | --- |
| Baseline | Preset aktual folder 32 dibekukan sebagai `folder32_v1` |
| Peran ML | Veto-only terhadap candidate yang sudah legacy-ready |
| Primary barrier | `+1 ATR` versus `-1 ATR`, first touch, horizon 50 candle M1 |
| Sensitivity barrier | Definisi sama, horizon 40 candle M1 |
| ATR barrier | RMA 14 M1 dari candle tertutup terakhir saat candidate |
| Primary business target | Meningkatkan `NO_RECOVERY` |
| Deep-risk diagnostic | Mengurangi `RECOVERY_L4_PLUS`; model khusus L4+ ditunda hingga sampel cukup |
| Data split | Chronological walk-forward, bukan random split |
| Leakage boundary | Purge/embargo minimal 50 candle M1 dan grouping per signal/cycle |
| Account context | Boleh menjadi metadata, bukan feature model pertama |
| Hypothetical outcome | Hanya barrier price-path, bukan P/L atau recovery aktual |
| Model | Logistic Regression wajib; tree model/XGBoost adalah kandidat |
| Deployment | ONNX adalah kandidat dan harus lulus prototype parity terlebih dahulu |
| Vision | Di luar scope model pertama |
| Compound | Tetap OFF selama penelitian, OOS, dan forward validation |

Primary horizon selalu 50. Horizon 40 hanya mengukur sensitivity; hasil yang lebih menarik pada
horizon 40 tidak boleh digunakan untuk mengganti primary label setelah test dibuka.

## 3. Baseline `folder32_v1`

Manifest lengkap dan bukti artefak berada di
[ml-folder32-v1-baseline.md](ml-folder32-v1-baseline.md).

Hal penting:

- folder 32 memakai ATR candle initial SL;
- formula BUY adalah low candle tertutup sebelumnya dikurangi ATR RMA 14 dikali 1.4;
- formula SELL adalah high candle tertutup sebelumnya ditambah ATR RMA 14 dikali 1.4;
- folder 32 juga mengubah beberapa setting lain dari folder 25;
- karena itu folder 32 adalah baseline ML baru, bukan bukti kausal bahwa ATR SL sendirian
  menghasilkan performanya;
- run dengan preset berbeda harus memakai `strategy_version` berbeda dan tidak boleh langsung
  digabungkan.

Source defaults di `Inputs.mqh` bukan pengganti preset baseline. Semua pengumpulan data
`folder32_v1` wajib memuat preset yang cocok dengan manifest dan mencatat hash preset.

## 4. Titik keputusan dan event taxonomy

Alur model pertama:

~~~text
CCI valid
  -> HiLo + PSAR + SuperTrend M1 + SuperTrend M5 searah
  -> operational legacy guards lolos
  -> initial SL candidate berhasil dihitung
  -> ENTRY_CANDIDATE + feature snapshot
  -> ML score
  -> ALLOW: lanjut lot/risk check dan kirim order
  -> REJECT: jangan kirim order, tetap track hypothetical barrier
~~~

Event harus dibedakan:

| Event | Definisi | Masuk training v1 |
| --- | --- | --- |
| `SIGNAL_OBSERVATION` | CCI terlihat tetapi konfirmasi belum lengkap, kedaluwarsa, atau tertolak hard guard | Tidak |
| `ENTRY_CANDIDATE` | Seluruh aturan baseline siap entry, tepat sebelum keputusan ML/order | Ya, jika label valid |
| `TRADE_ENTRY` | Hasil permintaan order candidate | Metadata/outcome |
| `TRADE_OUTCOME` | Original trade benar-benar selesai | Label bisnis |
| `CYCLE_OUTCOME` | Original beserta recovery terkait selesai | Label bisnis |
| `BARRIER_OUTCOME` | First-touch price path 40/50 candle | Label entry quality |

Pemisahan ini mencegah model dilatih dari campuran sinyal mentah dan setup yang sebenarnya belum
pernah diizinkan strategi.

## 5. Identitas record

Setiap candidate memiliki ID deterministik yang tersusun dari:

- `strategy_version`;
- symbol;
- timeframe;
- arah;
- CCI signal close time;
- candidate bar open time.

Contoh:

~~~text
folder32_v1_GOLD-i_M1_BUY_20260724T103400_20260724T103700
~~~

Sequence number, ticket, atau urutan file tidak boleh menjadi satu-satunya identitas karena dapat
berubah antar-run. Kolom minimum:

- `SchemaVersion`;
- `RunId`;
- `SetupId`;
- `CycleId` jika trade dieksekusi;
- `StrategyVersion`;
- source commit dan preset hash;
- symbol, timeframe, timezone;
- signal time, candidate time, direction;
- readiness, event type, reason code;
- model version, score, threshold, dan decision bila inference aktif.

## 6. Kontrak barrier label

### 6.1 Reference price

Candidate terjadi pada tick awal ketika baseline akan mengirim order:

- BUY memakai Ask sebagai candidate entry reference dan Bid untuk menilai exit barrier;
- SELL memakai Bid sebagai candidate entry reference dan Ask untuk menilai exit barrier.

Dengan demikian spread tetap tercermin. Untuk trade yang benar-benar dieksekusi, actual fill dan
slippage disimpan terpisah, tetapi barrier candidate tetap memakai reference price agar candidate
ALLOW dan REJECT dapat dibandingkan secara konsisten.

### 6.2 ATR

`BarrierAtr` menggunakan ATR RMA 14 M1 dari candle tertutup terakhir pada waktu candidate. ATR
harus finite dan lebih besar dari nol. Record dengan ATR tidak siap diberi `LABEL_DATA_ERROR` dan
tidak masuk training.

### 6.3 First-touch

Untuk BUY:

~~~text
favorable = candidate Ask + 1.0 * BarrierAtr
adverse   = candidate Ask - 1.0 * BarrierAtr
~~~

Untuk SELL:

~~~text
favorable = candidate Bid - 1.0 * BarrierAtr
adverse   = candidate Bid + 1.0 * BarrierAtr
~~~

Status:

- `FAVORABLE_FIRST`;
- `ADVERSE_FIRST`;
- `UNRESOLVED`;
- `AMBIGUOUS`;
- `LABEL_DATA_ERROR`.

Primary horizon dimulai pada tick candidate dan berakhir pada penutupan candle M1 ke-50, dengan
candle yang baru dibuka saat candidate dihitung sebagai candle pertama. Sensitivity horizon
berakhir pada penutupan candle ke-40.

Real-tick ordering menentukan first touch. Jika sumber data hanya OHLC dan kedua barrier tersentuh
dalam candle yang sama, hasil harus `AMBIGUOUS`, bukan ditebak. `UNRESOLVED`, `AMBIGUOUS`, dan
`LABEL_DATA_ERROR` tidak dimasukkan ke binary training awal, tetapi jumlahnya wajib dilaporkan.

Barrier simetris mengukur timing/arah entry tanpa mengikuti lebar initial SL folder 32 yang
bervariasi. Initial SL aktual tetap dicatat sebagai feature candidate dan konteks evaluasi.

## 7. Kontrak outcome bisnis

Satu cycle dimulai dari original trade dan berakhir ketika original selesai tanpa recovery atau
seluruh exposure recovery terkait selesai/reset.

| Label | Definisi |
| --- | --- |
| `NO_RECOVERY` | Cycle selesai tanpa recovery pernah dimulai |
| `RECOVERY_L1_L3` | Recovery dimulai dan maximum executed level 1 sampai 3 |
| `RECOVERY_L4_PLUS` | Recovery pernah mengeksekusi level 4 atau lebih |
| `INCOMPLETE` | Cycle belum selesai atau pasangan datanya tidak valid |

`INCOMPLETE` tidak masuk training. Maximum level ditentukan dari posisi recovery yang benar-benar
dieksekusi, bukan order attempt.

Outcome bisnis dipengaruhi initial SL, trailing, spread, dan recovery. Karena itu outcome ini
menilai manfaat model bagi EA, sedangkan barrier simetris menilai kualitas arah/timing candidate.
Keduanya dilaporkan bersama.

## 8. Hypothetical outcome

Candidate yang ditolak ML tidak menghasilkan trade aktual. Untuk candidate tersebut, logger tetap
menghitung `BARRIER_OUTCOME` dari tick harga.

Nilai hypothetical tidak boleh disebut:

- realized profit;
- trade win/loss aktual;
- recovery depth;
- drawdown akun;
- cycle result.

Menolak satu trade dapat mengubah posisi aktif, balance, recovery, daily target, dan kesempatan
entry setelahnya. Dampak portofolio hanya sah setelah Strategy Tester dijalankan ulang dalam
`ML_FILTER`.

## 9. Feature set versi pertama

Semua feature harus tersedia saat `ENTRY_CANDIDATE`, memakai candle tertutup, dan memiliki definisi
satuan serta direction normalization yang identik di MQL5 dan Python.

### Sinyal dan confirmation

- direction;
- tipe CCI normal/strong;
- signal age;
- raw CCI dan smoothed CI saat signal dan candidate;
- perubahan CCI;
- alignment mask pada signal-close;
- confirmation latency HiLo, PSAR, ST M1, dan ST M5;
- jumlah confirmation yang belum aligned pada signal-close;
- late-confirmation mask 5;
- trend-state age.

Confirmation latency M1 dinyatakan dalam jumlah candle M1 tertutup. Latency M5 juga disimpan dalam
native M5 bars dan ekuivalen elapsed seconds agar tidak ambigu.

### Price action, volatility, dan execution

- return 1/3/5/10/20 candle direction-normalized;
- candle body, range, upper/lower wick dalam ATR;
- displacement signal-to-candidate dalam ATR;
- pre-entry MFE/MAE antara signal dan candidate;
- ATR M1, ATR M5, dan ratio;
- posisi dalam recent range;
- distance dan slope EMA dalam ATR;
- confirmed-pivot directional room;
- spread points dan spread/ATR;
- tick volume;
- initial SL distance points dan ATR.

Pre-entry MFE/MAE aman sebagai feature karena hanya memakai harga dari signal sampai candidate.
Nama field harus menyertakan `PreEntry` agar tidak tertukar dengan excursion setelah entry.

### Waktu

- hour/minute dalam cyclical encoding;
- day of week;
- session;
- jarak dari session open/close;
- data-integrity flag.

## 10. Metadata yang dilarang menjadi feature v1

Kolom berikut boleh dicatat untuk audit tetapi tidak masuk feature:

- balance, equity, daily profit, dan daily drawdown;
- existing position count;
- recovery state dan recovery wait state;
- ticket, setup ID, cycle ID, strategy version, model version;
- tanggal mentah;
- MFE/MAE setelah entry;
- exit price/reason, profit, swap, commission;
- recovery started/depth;
- future return dan barrier outcome;
- nilai apa pun dari candle setelah candidate.

Larangan account/recovery context menjaga model tetap belajar kualitas setup, bukan ukuran akun atau
keadaan recovery.

## 11. File data

Logger Fase 1 akan menghasilkan file terpisah:

~~~text
candidate_setups.csv
trade_entries.csv
trade_outcomes.csv
cycle_outcomes.csv
barrier_outcomes.csv
run_manifest.json
~~~

File digabungkan memakai `SetupId` dan `CycleId`. Journal tetap menyediakan summary, tetapi bukan
sumber dataset utama.

Data mentah disimpan di luar Git:

~~~text
<local-ml-data>/
  raw/<run-id>/
  processed/<dataset-version>/
  artifacts/<experiment-id>/
~~~

Repository hanya menyimpan schema, script, konfigurasi nonprivat, hash/manifest, laporan agregat,
dan keputusan eksperimen. Raw report, terminal journal, nomor akun, credential, screenshot akun,
`.ex5`, serta dataset privat tidak di-commit.

## 12. Data integrity dan leakage prevention

Aturan wajib:

1. Split selalu chronological; random split dilarang.
2. Walk-forward hanya melatih dari data sebelum test window.
3. Beri purge/embargo minimal 50 candle M1 di setiap batas split.
4. Semua observasi dari CCI signal yang sama berada pada split yang sama.
5. Original trade dan seluruh recovery cycle terkait berada pada split yang sama.
6. Normalizer, imputer, feature selector, calibration, serta class weight di-fit hanya pada train.
7. Threshold dipilih pada validation/walk-forward, bukan final out-of-sample.
8. Out-of-sample dibuka sekali setelah feature, model, dan threshold dibekukan.
9. Duplicate run pada tick/periode yang sama tidak dihitung sebagai sampel independen.
10. Hasil BUY/SELL, signal type, session, bulan, dan volatility regime dilaporkan terpisah.

Interval yang terkait migrasi `GOLD#` ke `GOLD.i#` diberi `DataIntegrityFlag`. Sampai tanggal
discontinuity dapat dibuktikan, dataset utama harus melaporkan sensitivity dengan dan tanpa
interval yang dicurigai; model tidak boleh diterima bila kesimpulannya hanya bertahan pada salah
satunya.

## 13. Penelitian dan model

Urutan:

1. `folder32_v1` tanpa ML sebagai control;
2. analisis rule signal age, latency, displacement, CCI type, session, spread/ATR, dan regime;
3. rule mask-5 sebagai deterministic baseline;
4. Logistic Regression dengan regularization;
5. Random Forest atau shallow gradient boosting;
6. XGBoost sebagai kandidat jika data dan runtime mendukung.

Deep learning dan vision tidak masuk tahap pertama. Model yang lebih kompleks hanya diteruskan
bila meningkatkan hasil walk-forward secara stabil dibanding Logistic Regression dan rule
sederhana.

Metrik ML:

- PR-AUC dan ROC-AUC;
- precision/recall per class;
- log loss dan Brier score;
- calibration curve;
- confusion matrix;
- stability per time window/subgroup.

Jumlah kasar:

- di bawah 500 candidate: diagnosis, bukan training final;
- 500-1.000: eksplorasi model sederhana;
- 2.000-5.000: target awal penelitian model;
- pengulangan periode yang sama tidak menambah jumlah independen.

## 14. Acceptance gate

Gate berikut dibekukan sebelum training:

| Metrik out-of-sample | Gate |
| --- | ---: |
| Winner legacy yang ditolak | maksimal 10% |
| Recovery L4+ yang ditolak | minimal 20% |
| Original win rate | naik minimal 3 percentage points |
| Recovery entry rate | turun minimal 10% secara relatif |
| Active trading weekdays | tetap minimal 80% |
| Profit factor | tidak turun lebih dari 5% |
| Net profit | tidak turun lebih dari 10% |
| Maximum equity drawdown | tidak memburuk |
| Stop-out/forced liquidation | 0 |

Model tidak lolos bila hanya memperbaiki metrik klasifikasi. Expectancy, jumlah trade, average
win/loss, consecutive losses, time in market, recovery carried overnight, serta calibration tetap
harus dilaporkan.

## 15. Runtime dan ONNX

ONNX belum dianggap pasti. Sebelum arsitektur dikunci:

1. ekspor model prototype kecil;
2. bandingkan native Python probability;
3. bandingkan ONNX Runtime Python;
4. bandingkan MQL5 inference untuk feature vectors yang sama;
5. buktikan operator model didukung dan urutan feature identik.

Jika ONNX tree model tidak stabil/didukung, fallback adalah model sederhana yang diekspor sebagai
coefficient/rule artifact dan dihitung di MQL5. Service Python eksternal tidak menjadi dependency
live wajib.

`ML_OFF` harus mereproduksi control. `ML_SHADOW` harus menghasilkan trade yang sama dengan
`ML_OFF`, serta score Python/MQL5 harus sama dalam toleransi yang ditentukan sebelum
`ML_FILTER` dibuat.

## 16. Roadmap implementasi

### Fase 0 — Specification and baseline freeze

Status: selesai.

- konsolidasikan handoff dan koreksi;
- bekukan `folder32_v1`;
- kunci label 50/40, outcome bisnis, leakage rules, dan acceptance gate;
- tandai XGBoost/ONNX sebagai kandidat;
- pastikan tidak ada perubahan perilaku trading.

### Fase 1 — Data contract and observation-only logger

- buat schema CSV/JSON resmi;
- implementasikan `StrategyVersion`, `RunId`, `SetupId`, dan `CycleId`;
- simpan trigger state, confirmation latency, dan candidate feature;
- implementasikan entry/outcome/cycle logger;
- implementasikan real-tick barrier tracker 40/50;
- validasi missing value dan reason code;
- buktikan logger ON/OFF menghasilkan history trade identik.

### Fase 2 — Historical dataset and audit

- kumpulkan beberapa periode/regime dengan preset identik;
- validasi hash, duplicate ID, pairing, missing values, dan label;
- audit discontinuity symbol;
- analisis rule sederhana sebelum ML.

### Fase 3 — Offline baseline models

- siapkan pipeline reproducible;
- chronological walk-forward dengan purge/embargo;
- latih Logistic Regression dan tree challengers;
- kalibrasi probability;
- pilih feature/model/threshold hanya dari train/validation.

### Fase 4 — Frozen out-of-sample

- bekukan candidate model;
- buka final OOS satu kali;
- nilai seluruh acceptance gate;
- catat gagal tanpa mengubah OOS menjadi validation tersembunyi.

### Fase 5 — Runtime prototype and shadow

- buktikan ONNX atau fallback runtime;
- uji parity feature dan probability;
- jalankan Strategy Tester `ML_SHADOW`;
- lanjut demo shadow dengan fixed minimum lot.

### Fase 6 — Filter validation

- jalankan Strategy Tester `ML_FILTER`;
- ukur actual portfolio result, bukan hypothetical barrier saja;
- lanjut demo filter hanya bila OOS dan parity lolos;
- compound tetap OFF.

### Fase 7 — Champion/challenger operation

- retrain secara batch, bukan setiap trade;
- model baru menjadi challenger;
- promotion hanya setelah walk-forward, recent-data, drawdown, dan calibration review;
- version/checksum/rollback wajib tersedia.

### Fase 8 — Future research

- model recovery memakai dataset dan label terpisah;
- vision market-regime model hanya setelah tabular model stabil;
- decision fusion dan compound menjadi proyek terpisah.

## 17. Definition of done model pertama

Model pertama selesai bila:

- dataset candidate reproducible dan setiap ID unik;
- logger observation-only tidak mengubah trade;
- label 50/40 dan business outcome valid;
- tidak ada look-ahead leakage;
- Logistic Regression dan tree candidate dibandingkan secara walk-forward;
- model probability terkalibrasi;
- runtime parity terbukti;
- shadow test identik dengan baseline;
- filter melewati acceptance gate pada OOS;
- forward demo stabil;
- model/schema memiliki version, checksum, dan rollback.

Jika salah satu syarat kritis gagal, EA tetap menggunakan `ML_OFF`.
