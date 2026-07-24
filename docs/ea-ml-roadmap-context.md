# EA Machine Learning Roadmap Context

> Status: handoff context dari diskusi awal. Dokumen ini dipertahankan sebagai sumber gagasan,
> bukan spesifikasi normatif. Keputusan yang sudah dikoreksi dan dikunci tersedia di
> [machine-learning-plan.md](machine-learning-plan.md), sedangkan konfigurasi aktual folder 32
> tersedia di [ml-folder32-v1-baseline.md](ml-folder32-v1-baseline.md). Jika ada konflik, kedua
> dokumen tersebut yang berlaku.

## 1. Tujuan Dokumen

Dokumen ini menjadi konteks utama untuk pengembangan integrasi machine learning pada Expert Advisor MT5.

Target utamanya bukan membuat model yang mencoba meramal seluruh pergerakan market dari nol. Target tahap pertama adalah membangun **machine learning meta-filter** yang menilai apakah kandidat entry original dari EA layak diambil atau ditolak.

Dokumen ini harus digunakan sebagai acuan oleh developer atau coding agent saat:

- memodifikasi EA MQL5;
- membuat logger dataset;
- membuat pipeline Python;
- melatih model XGBoost;
- melakukan evaluasi walk-forward;
- mengekspor model ke ONNX;
- mengintegrasikan model ke MT5 Strategy Tester;
- melakukan forward test dan retraining.

---

# 2. Ringkasan Strategi EA Saat Ini

## 2.1 Arsitektur entry original

Strategi entry original menggunakan:

```text
CCI sebagai pemicu utama
        ↓
Sinyal berlaku maksimal N candle tertutup
        ↓
HiLo + PSAR + SuperTrend M1 + SuperTrend M5 harus searah
        ↓
ADX mengonfirmasi arah jika diaktifkan
        ↓
Lolos filter operasional
        ↓
Entry pada awal candle M1 berikutnya
```

Strategi ini secara konseptual adalah:

> CCI-triggered delayed trend confirmation system.

CCI mendeteksi peluang reversal atau momentum lebih awal. Indikator lain menunggu sampai arah market dianggap terkonfirmasi.

---

## 2.2 Syarat BUY original

BUY original hanya boleh terjadi jika:

1. CCI menghasilkan sinyal BUY normal atau strong.
2. Sinyal CCI belum pernah digunakan.
3. Sinyal masih berada dalam `InpCciSignalValidityBars`.
4. HiLo bullish.
5. Harga berada di atas Parabolic SAR.
6. SuperTrend M1 bullish.
7. SuperTrend M5 bullish.
8. ADX mengizinkan BUY jika ADX diaktifkan.
9. EA tidak sedang dalam recovery.
10. EA tidak sedang menunggu recovery.
11. Lolos jam trading.
12. Lolos session filter.
13. Lolos batas posisi.
14. Lolos daily target.
15. Lolos recovery cooldown.
16. Entry dilakukan pada awal candle M1 berikutnya.

SELL menggunakan aturan yang sama dengan arah berlawanan.

---

## 2.3 Peran CCI

CCI bukan sekadar filter arah.

CCI adalah trigger utama yang dapat menghasilkan:

- normal BUY;
- strong BUY;
- normal SELL;
- strong SELL.

Mode sinyal ditentukan oleh:

```text
InpCciSignalMode
```

EA membaca candle tertutup dari shift 1 hingga jumlah validity. Entry tidak harus terjadi langsung setelah sinyal CCI.

Contoh:

```text
Candle 1: CCI BUY muncul
Candle 2: konfirmasi belum lengkap
Candle 3: seluruh indikator bullish
Candle 4: EA membuka BUY
```

---

## 2.4 Konfigurasi baseline folder 32

Konfigurasi baseline yang saat ini digunakan:

```text
InpCciSignalValidityBars    = 5
CCI normal                  = aktif
CCI strong                  = aktif
HiLo                        = aktif
Parabolic SAR               = aktif
SuperTrend M1               = aktif
SuperTrend M5               = aktif
ADX                         = nonaktif
InpEnableLateConfirmationGuard = false
```

Konfigurasi ini harus dianggap sebagai baseline awal selama proses pengumpulan dataset.

Tambahkan identifier versi strategi:

```text
strategy_version = folder32_v1
```

Setiap perubahan besar terhadap aturan entry, filter, SL, trailing, atau recovery harus menghasilkan `strategy_version` baru.

---

## 2.5 Risiko late confirmation

Dengan validity 5 candle, sinyal CCI dapat menunggu sampai lima candle tertutup agar seluruh indikator menjadi searah.

Keuntungannya:

- lebih banyak sinyal memperoleh konfirmasi;
- frekuensi entry meningkat;
- sinyal CCI tidak cepat kedaluwarsa.

Risikonya:

- entry dapat terjadi setelah harga sudah bergerak jauh;
- risk-to-reward memburuk;
- model entry dapat membeli di ujung gerakan bullish;
- HiLo dan SuperTrend M1 bisa terlambat menyusul;
- indikator searah tidak otomatis berarti entry masih berkualitas.

Late Confirmation Guard saat ini OFF. Artinya pola berikut tetap boleh masuk:

```text
CCI BUY muncul
HiLo belum bullish
SuperTrend M1 belum bullish
harga bergerak naik
HiLo dan SuperTrend M1 baru berubah bullish
EA membuka BUY
```

Machine learning terutama diharapkan membantu membedakan konfirmasi sehat dan konfirmasi terlambat.

---

## 2.6 Trade management setelah entry

Setelah original entry:

```text
Initial SL = ATR periode 14 × 1.4
TP tetap   = 0
```

Posisi kemudian dikelola oleh:

- trailing stop;
- break-even;
- recovery setelah original trade ditutup rugi.

ATR tidak menentukan validitas entry. ATR hanya menentukan jarak initial SL.

Performa baseline dapat terlihat lebih baik bukan hanya karena kualitas entry, tetapi karena SL ATR yang relatif lebar memberi posisi lebih banyak ruang.

---

# 3. Tujuan Machine Learning Tahap Pertama

## 3.1 Tugas model

Model pertama harus menjawab pertanyaan sempit:

> Berdasarkan kondisi saat candidate original entry terbentuk, apakah setup ini layak diambil?

Jenis model:

```text
Learning type  : Supervised learning
Task           : Binary classification
Primary model  : XGBoost
Baseline model : Logistic Regression
Challenger     : Random Forest / LightGBM
Output         : Probability setup success
Deployment     : ONNX dalam EA MQL5
```

Model tidak boleh langsung menggantikan:

- CCI;
- HiLo;
- PSAR;
- SuperTrend;
- risk management;
- recovery engine.

Model hanya bertindak sebagai **quality filter**.

---

## 3.2 Arsitektur final tahap pertama

```text
CCI trigger
    ↓
Signal tracking selama validity
    ↓
HiLo + PSAR + ST M1 + ST M5 confirmation
    ↓
Operational filters
    ↓
Candidate original entry
    ↓
Feature builder
    ↓
XGBoost probability
    ↓
Decision gate
    ↓
Risk engine
    ↓
Open original trade
```

Output decision gate:

```text
ALLOW
REJECT
```

Tahap awal dapat menggunakan shadow mode agar prediksi dicatat tetapi tidak memblokir trade.

---

# 4. Prinsip Dataset

## 4.1 Unit data

Satu baris dataset mewakili:

> Satu candidate original entry.

Bukan satu candle.

Bukan satu tick.

Bukan satu posisi recovery.

---

## 4.2 Setup ID

Setiap kandidat harus memiliki ID unik.

Format contoh:

```text
XAUUSD_20260724_103500_BUY_00001
```

Kolom:

```text
setup_id
```

`setup_id` harus menghubungkan:

- candidate feature snapshot;
- order entry;
- trade outcome;
- screenshot;
- label;
- model prediction;
- hypothetical outcome untuk trade yang ditolak.

---

## 4.3 Dataset harus menyimpan kandidat, bukan hanya trade

Simpan:

- kandidat yang dieksekusi;
- kandidat yang ditolak model;
- kandidat yang gagal order;
- kandidat yang kedaluwarsa;
- kandidat yang gagal konfirmasi;
- kandidat yang tertolak filter operasional jika relevan untuk analisis.

Namun model entry tahap pertama sebaiknya dilatih dari kandidat yang sudah mencapai titik keputusan entry dan memiliki outcome yang dapat dihitung.

---

# 5. Logging di EA

Disarankan menggunakan tiga file terpisah:

```text
candidate_setups.csv
trade_entries.csv
trade_outcomes.csv
```

Ketiganya digabungkan berdasarkan `setup_id`.

---

# 6. Candidate Setup Logger

Logger dipanggil saat seluruh syarat rule-based entry original sudah lengkap, tepat sebelum keputusan ML atau order.

## 6.1 Informasi dasar

```text
setup_id
strategy_version
timestamp
symbol
direction
timeframe
```

Encoding:

```text
BUY  = 1
SELL = -1
```

---

## 6.2 CCI features

```text
cci_signal_type
cci_value_at_signal
cci_value_at_candidate
cci_slope
cci_change_since_signal
signal_age
```

Encoding:

```text
normal = 0
strong = 1
```

`signal_age` adalah jumlah candle tertutup sejak sinyal CCI muncul hingga candidate entry terbentuk.

---

## 6.3 Confirmation latency features

```text
bars_until_hilo_confirm
bars_until_psar_confirm
bars_until_st_m1_confirm
bars_until_st_m5_confirm
bars_until_all_confirm
```

Definisi:

```text
0 = indikator sudah searah saat trigger CCI
1 = indikator baru searah satu candle setelah trigger
2 = indikator baru searah dua candle setelah trigger
...
```

---

## 6.4 Indicator state at trigger

```text
hilo_aligned_at_trigger
psar_aligned_at_trigger
st_m1_aligned_at_trigger
st_m5_aligned_at_trigger
confirmations_at_trigger
```

Encoding:

```text
1 = searah dengan kandidat
0 = belum searah
```

---

## 6.5 Indicator state at candidate entry

```text
hilo_direction
psar_direction
st_m1_direction
st_m5_direction
adx_value
adx_direction
```

Walaupun seluruh indikator wajib searah saat candidate entry, nilai aktual atau kekuatan indikator tetap dapat menjadi fitur.

---

## 6.6 Price displacement features

```text
trigger_price
candidate_entry_price
price_move_since_trigger
price_move_since_trigger_atr
mfe_before_entry
mae_before_entry
same_direction_candles
distance_from_recent_swing_atr
```

Gunakan directional normalization:

```text
direction_sign = 1 untuk BUY
direction_sign = -1 untuk SELL

directional_move =
(candidate_entry_price - trigger_price) × direction_sign
```

Dengan normalisasi ini:

```text
nilai positif = harga sudah bergerak sesuai arah setup
nilai negatif = harga bergerak melawan arah setup
```

Rumus normalisasi ATR:

```text
price_move_since_trigger_atr =
directional_move / atr_at_trigger
```

---

## 6.7 Volatility and execution context

```text
atr_m1
atr_m5
atr_ratio_m1_m5
spread_points
spread_price
spread_atr_ratio
tick_volume
```

---

## 6.8 Time and session features

```text
hour
minute
day_of_week
session
```

Contoh encoding:

```text
Asia       = 0
London     = 1
New York   = 2
Overlap    = 3
Other      = 4
```

Encoding final harus konsisten antara Python dan MQL5.

---

## 6.9 Risk and account context

```text
initial_sl_distance
initial_sl_atr
existing_positions
daily_profit_before_entry
daily_drawdown_before_entry
recovery_state
recovery_wait_state
```

Model pertama hanya untuk original entry.

Jangan melatih model recovery menggunakan dataset yang sama.

---

# 7. Trade Entry Logger

File:

```text
trade_entries.csv
```

Kolom:

```text
setup_id
ticket
entry_time
requested_entry_price
actual_entry_price
initial_sl_price
initial_sl_distance
spread_at_entry
slippage_entry
order_result
order_error_code
```

Tujuan file ini adalah membedakan candidate entry dengan order aktual.

---

# 8. Trade Outcome Logger

File:

```text
trade_outcomes.csv
```

Kolom:

```text
setup_id
ticket
exit_time
exit_price
exit_reason
gross_profit
commission
swap
net_profit
bars_in_trade
mfe_after_entry
mae_after_entry
break_even_triggered
trailing_triggered
recovery_started
```

Contoh `exit_reason`:

```text
INITIAL_SL
TRAILING_STOP
BREAK_EVEN
MANUAL_CLOSE
SESSION_CLOSE
DAILY_TARGET
OTHER
```

---

# 9. Labeling Strategy

## 9.1 Jangan hanya memakai profit akhir

Label sederhana:

```text
1 = net_profit > 0
0 = net_profit <= 0
```

boleh disimpan, tetapi jangan menjadi satu-satunya target karena hasil dipengaruhi trailing stop dan break-even.

---

## 9.2 Label utama: entry quality barrier

Model utama sebaiknya menggunakan label objektif berbasis barrier.

Contoh:

```text
Upper barrier = entry + 1.0 ATR
Lower barrier = initial SL
Time barrier  = 30 candle M1
```

Untuk SELL, arah upper/lower dibalik secara directional.

Label binary:

```text
1 = profit barrier tersentuh sebelum initial SL
0 = initial SL tersentuh sebelum profit barrier
```

Jika tidak ada barrier tersentuh hingga time barrier:

```text
unresolved = 1
```

Pada model binary versi pertama, data unresolved dapat:

- dikeluarkan dari training; atau
- dianalisis terpisah.

Jangan mengubah unresolved menjadi loss tanpa keputusan metodologis yang jelas.

---

## 9.3 Label tambahan

Simpan:

```text
label_trade_profit
label_entry_quality
barrier_outcome
future_return_atr
mfe_atr
mae_atr
```

---

# 10. Dataset Final

Setelah file digabungkan, bentuk:

```text
training_dataset.csv
```

Satu baris contoh:

```text
setup_id
timestamp
direction
cci_signal_type
cci_value_at_signal
signal_age
bars_until_all_confirm
confirmations_at_trigger
price_move_since_trigger_atr
mfe_before_entry
mae_before_entry
atr_m1
atr_m5
spread_atr_ratio
session
initial_sl_atr
label_entry_quality
net_profit
mfe_after_entry
mae_after_entry
```

---

# 11. Data Leakage Rules

Fitur model hanya boleh menggunakan data yang tersedia pada waktu candidate entry.

Kolom yang tidak boleh menjadi feature:

```text
exit_price
exit_reason
net_profit
gross_profit
bars_in_trade
mfe_after_entry
mae_after_entry
break_even_triggered
trailing_triggered
recovery_started
future_return_atr
label_entry_quality
```

Kolom tersebut hanya untuk:

- label;
- evaluasi;
- analisis outcome.

Semua indikator untuk feature inference harus menggunakan candle tertutup.

---

# 12. Pengumpulan Dataset

## 12.1 Baseline harus dibekukan

Selama pengumpulan dataset awal, jangan mengubah:

- CCI logic;
- validity;
- indikator konfirmasi;
- SL;
- break-even;
- trailing;
- recovery;
- filter session.

Jika berubah, gunakan `strategy_version` baru.

---

## 12.2 Gunakan Strategy Tester

Dataset awal sebaiknya dibentuk dari MT5 Strategy Tester.

Tahapan:

```text
1. Jalankan EA baseline tanpa ML
2. Aktifkan candidate logger
3. Aktifkan entry logger
4. Aktifkan outcome logger
5. Jalankan historical backtest
6. Export CSV
```

Gunakan tick quality dan spread yang realistis.

Mulai dengan satu simbol utama.

---

## 12.3 Target jumlah data

Panduan kasar:

```text
< 300 setup      = terlalu sedikit
500–1.000 setup  = eksplorasi awal
2.000–5.000      = mulai layak
10.000+          = lebih baik
```

Kualitas label dan konsistensi strategi lebih penting daripada jumlah mentah.

---

# 13. Analisis Sebelum Training

Sebelum training ML, analisis rule sederhana.

Minimal analisis:

```text
win rate berdasarkan signal_age
profit factor berdasarkan signal_age
hasil berdasarkan displacement ATR
normal CCI vs strong CCI
hasil berdasarkan session
hasil berdasarkan confirmations_at_trigger
hasil berdasarkan bars_until_all_confirm
hasil berdasarkan spread_atr_ratio
hasil berdasarkan ATR regime
```

Jika ditemukan aturan sederhana yang stabil, contoh:

```text
signal_age >= 4 memiliki expectancy negatif konsisten
```

maka pertimbangkan rule deterministic sebelum ML.

ML hanya diperlukan jika interaksi fitur cukup kompleks.

---

# 14. Python Project Structure

Gunakan struktur:

```text
ea_ml_project/
├── data/
│   ├── raw/
│   └── processed/
├── models/
├── reports/
├── notebooks/
├── src/
│   ├── prepare_dataset.py
│   ├── validate_dataset.py
│   ├── analyze_features.py
│   ├── train_baselines.py
│   ├── train_xgboost.py
│   ├── evaluate_trading.py
│   ├── walk_forward.py
│   ├── export_onnx.py
│   └── parity_test.py
├── requirements.txt
└── README.md
```

Library:

```text
pandas
numpy
scikit-learn
xgboost
matplotlib
joblib
onnx
onnxruntime
onnxmltools
shap
```

Install:

```bash
pip install pandas numpy scikit-learn xgboost matplotlib joblib onnx onnxruntime onnxmltools shap
```

---

# 15. Data Preparation

## 15.1 Merge

Gabungkan:

```text
candidate_setups.csv
trade_entries.csv
trade_outcomes.csv
```

berdasarkan:

```text
setup_id
```

---

## 15.2 Validation

Periksa:

```text
duplicate setup_id
missing values
invalid timestamps
ATR <= 0
spread < 0
signal_age > validity
bars_until_confirm < 0
invalid direction encoding
unmatched trade tickets
```

Jangan otomatis mengganti semua missing value dengan nol.

---

## 15.3 Time sorting

Dataset wajib diurutkan:

```text
timestamp ascending
```

---

# 16. Feature Set Versi Pertama

Gunakan 15–25 fitur.

Contoh:

```text
direction
cci_signal_type
cci_value_at_signal
cci_value_at_candidate
cci_slope
signal_age
confirmations_at_trigger
bars_until_hilo_confirm
bars_until_psar_confirm
bars_until_st_m1_confirm
bars_until_st_m5_confirm
bars_until_all_confirm
price_move_since_trigger_atr
mfe_before_entry
mae_before_entry
atr_m1
atr_m5
atr_ratio_m1_m5
spread_atr_ratio
tick_volume
hour
day_of_week
session
initial_sl_atr
```

Target:

```text
label_entry_quality
```

---

# 17. Dataset Split

Jangan menggunakan random split.

Gunakan time-based split:

```text
Train      = 60% periode awal
Validation = 20% berikutnya
Test       = 20% periode terakhir
```

Atau pembagian berdasarkan tanggal yang eksplisit.

Contoh:

```text
Train      : Januari–April
Validation : Mei
Test       : Juni
```

---

# 18. Model Training

Latih minimal tiga model.

## 18.1 Logistic Regression

Tujuan:

- baseline linear;
- menguji apakah fitur memiliki sinyal sederhana;
- menjadi pembanding kompleksitas.

## 18.2 Random Forest

Tujuan:

- baseline nonlinear;
- pembanding tree ensemble.

## 18.3 XGBoost

Tujuan:

- model utama meta-filter;
- mempelajari interaksi nonlinear antarfitur;
- menghasilkan probabilitas setup success.

Output:

```text
P(setup_success)
```

Contoh:

```text
0.78 = setup dinilai kuat
0.52 = setup netral
0.31 = setup dinilai lemah
```

---

# 19. Metrik Machine Learning

Jangan hanya menggunakan accuracy.

Gunakan:

```text
ROC-AUC
PR-AUC
Precision
Recall
Log Loss
Brier Score
Calibration curve
Confusion matrix
```

Untuk dataset class imbalance, PR-AUC lebih penting daripada accuracy.

---

# 20. Metrik Trading

Model dianggap berguna hanya jika meningkatkan hasil trading out-of-sample.

Evaluasi:

```text
number of candidate setups
number of accepted trades
number of rejected trades
net profit
profit factor
expectancy
maximum drawdown
average win
average loss
win rate
consecutive losses
recovery count
time in market
```

Tujuan utama:

```text
expectancy naik
profit factor naik
drawdown turun
recovery berkurang
trade count tetap cukup
```

Win rate saja bukan ukuran keberhasilan.

---

# 21. Threshold Selection

Uji beberapa threshold:

```text
0.40
0.45
0.50
0.55
0.60
0.65
0.70
```

Threshold tidak boleh dipilih dari net profit tertinggi pada satu periode.

Threshold harus dipilih berdasarkan:

- kestabilan walk-forward;
- expectancy;
- drawdown;
- profit factor;
- trade count;
- calibration.

---

# 22. Walk-Forward Validation

Contoh:

```text
Train Jan–Mar → Test April
Train Jan–Apr → Test Mei
Train Jan–Mei → Test Juni
Train Jan–Jun → Test Juli
```

Setiap periode test hanya boleh diprediksi oleh model yang dilatih menggunakan data sebelum periode tersebut.

Gabungkan seluruh prediksi out-of-sample untuk menghitung performa final.

---

# 23. Model Metadata

Setiap model harus memiliki metadata:

```text
model_version
strategy_version
training_period
validation_period
test_period
feature_order
label_definition
hyperparameters
threshold
metrics
created_at
```

Contoh:

```json
{
  "model_version": "xgb_entry_v1",
  "strategy_version": "folder32_v1",
  "label": "profit_1atr_before_initial_sl_within_30_bars",
  "threshold": 0.58
}
```

---

# 24. Shadow Mode

Sebelum model memblokir entry, jalankan shadow mode.

Flow:

```text
Candidate entry
    ↓
Build features
    ↓
Run model
    ↓
Log probability
    ↓
EA tetap entry
```

Tambahkan input:

```text
InpEnableMlFilter
InpMlShadowMode
InpMlThreshold
InpMlModelFile
InpLogMlCandidates
```

Dalam shadow mode:

```text
InpEnableMlFilter = false
InpMlShadowMode   = true
```

---

# 25. ONNX Integration

## 25.1 Alur deployment

```text
XGBoost Python
    ↓
Export ONNX
    ↓
ONNX Runtime Python test
    ↓
MQL5 ONNX parity test
    ↓
MT5 Strategy Tester
```

---

## 25.2 Feature order

Urutan fitur harus identik antara:

- training Python;
- ONNX model;
- feature builder MQL5.

Simpan urutan fitur dalam file metadata.

Bug urutan fitur dapat menghasilkan probabilitas yang salah tanpa error runtime.

---

## 25.3 Parity test

Bandingkan:

```text
Python XGBoost probability
Python ONNX probability
MQL5 ONNX probability
```

Gunakan 100–1.000 feature vector yang sama.

Perbedaan harus sangat kecil.

Jangan lanjut ke backtest filter jika parity belum valid.

---

# 26. MT5 Backtest Modes

Buat minimal tiga mode.

## Mode A: Baseline

```text
ML disabled
```

## Mode B: Shadow

```text
ML inference aktif
ML tidak memblokir entry
```

## Mode C: Filter

```text
ML inference aktif
entry hanya jika probability >= threshold
```

Bandingkan semua mode pada periode out-of-sample yang sama.

---

# 27. Rejected Candidate Tracking

Saat model menolak candidate entry, tetap simpan:

```text
setup_id
timestamp
direction
ml_probability
ml_threshold
feature_snapshot
rejection_reason
hypothetical_outcome
```

Hypothetical outcome harus dihitung dari data harga setelah kandidat, meskipun trade tidak dibuka.

Tanpa hypothetical outcome, kualitas rejection tidak dapat dievaluasi.

---

# 28. Recovery Rules

Model versi pertama hanya memfilter original entry.

Jangan langsung gunakan model yang sama untuk recovery.

Reason:

- recovery memiliki distribusi risiko berbeda;
- recovery terjadi setelah loss;
- fitur dan label recovery berbeda;
- mencampur original dan recovery dapat merusak interpretasi model.

---

# 29. Retraining

Saat trade selesai:

```text
feature + outcome ditambahkan ke dataset
```

Jangan langsung retrain setelah satu trade.

Gunakan batch retraining:

```text
setiap 200–500 candidate baru
atau
setiap bulan
```

Gunakan pola:

```text
Champion   = model aktif
Challenger = model baru
```

Challenger hanya menggantikan champion jika:

- lebih baik pada walk-forward;
- lebih baik pada data terbaru;
- drawdown tidak memburuk;
- performa tidak bergantung pada satu periode;
- calibration tidak memburuk.

---

# 30. Vision Model Roadmap

Vision bukan prioritas tahap pertama.

## 30.1 Fungsi vision model

Vision model dapat digunakan nanti untuk:

```text
bullish
bearish
sideways
```

atau:

```text
trend
range
transition
```

Vision tidak boleh langsung menggantikan XGBoost entry quality model.

---

## 30.2 Jangan gunakan screenshot manual sebagai sumber utama

Lebih baik:

```text
Historical OHLC
    ↓
Python render chart standar
    ↓
Fixed candle count
    ↓
Fixed zoom
    ↓
Fixed image size
    ↓
Automatic label
```

Keuntungannya:

- konsisten;
- dapat dibuat ulang;
- tidak ada noise UI;
- mudah menghasilkan ribuan gambar;
- mengurangi style leakage.

---

## 30.3 Vision label

Definisi bullish/bearish/sideways harus objektif.

Contoh:

```text
Input horizon      = 100 candle sebelumnya
Prediction horizon = 20 candle berikutnya

Bullish:
+1 ATR tersentuh sebelum -0.75 ATR

Bearish:
-1 ATR tersentuh sebelum +0.75 ATR

Sideways:
tidak ada barrier tersentuh selama 20 candle
```

Model:

```text
ResNet18
EfficientNet-B0
CNN kecil
```

Framework:

```text
PyTorch
torchvision
```

---

## 30.4 Fusion tahap lanjut

Setelah XGBoost dan vision model stabil:

```text
Rule engine direction
+
XGBoost setup probability
+
Vision market regime probability
    ↓
Decision fusion
```

Contoh:

```text
Rule engine = BUY
XGBoost setup quality = 0.72
Vision bearish probability = 0.15
Result = ALLOW
```

Vision dapat menjadi context filter atau veto, bukan pengambil keputusan tunggal.

---

# 31. Development Phases

## Phase 1 — Freeze baseline

- Bekukan folder32_v1.
- Tambahkan `strategy_version`.
- Jangan ubah rule selama dataset awal.

## Phase 2 — Instrumentation

- Buat `setup_id`.
- Implement candidate logger.
- Implement entry logger.
- Implement outcome logger.
- Implement MFE/MAE.
- Implement barrier label.

## Phase 3 — Historical dataset

- Jalankan Strategy Tester.
- Export CSV.
- Audit hasil.
- Kumpulkan minimal 1.000–5.000 candidate setup.

## Phase 4 — Offline analysis

- Analisis signal age.
- Analisis confirmation latency.
- Analisis displacement.
- Analisis session dan volatility.
- Temukan rule sederhana.

## Phase 5 — Baseline models

- Logistic Regression.
- Random Forest.
- XGBoost.
- Time-based split.

## Phase 6 — Validation

- ML metrics.
- Trading metrics.
- Walk-forward validation.
- Threshold analysis.
- Calibration.

## Phase 7 — ONNX

- Export.
- Python parity.
- MQL5 parity.
- Feature order validation.

## Phase 8 — Shadow backtest

- Model menghitung probabilitas.
- Model tidak memblokir entry.
- Bandingkan prediksi dengan outcome.

## Phase 9 — Filter backtest

- Uji beberapa threshold.
- Bandingkan dengan baseline.
- Fokus expectancy dan drawdown.

## Phase 10 — Forward test

- Demo account.
- Shadow mode.
- Filter mode.
- Monitor drift.

## Phase 11 — Retraining

- Batch data baru.
- Train challenger.
- Compare champion.
- Deploy hanya jika lebih baik.

## Phase 12 — Vision experiment

- Render chart dari OHLC.
- Automatic labeling.
- Train model vision.
- Integrasikan sebagai context filter.

---

# 32. Immediate Implementation Checklist

## EA MQL5

- [ ] Tambahkan `strategy_version`.
- [ ] Tambahkan generator `setup_id`.
- [ ] Simpan original CCI trigger state.
- [ ] Simpan indicator alignment at trigger.
- [ ] Hitung confirmation latency setiap indikator.
- [ ] Hitung signal age.
- [ ] Hitung directional displacement.
- [ ] Hitung displacement dalam ATR.
- [ ] Hitung MFE/MAE sebelum entry.
- [ ] Buat candidate CSV logger.
- [ ] Buat entry CSV logger.
- [ ] Buat outcome CSV logger.
- [ ] Buat barrier outcome calculator.
- [ ] Pisahkan original dan recovery records.
- [ ] Tambahkan shadow ML inputs.
- [ ] Tambahkan ONNX inference wrapper.
- [ ] Tambahkan rejected candidate logger.

## Python

- [ ] Buat project structure.
- [ ] Merge CSV.
- [ ] Validate dataset.
- [ ] Check duplicates.
- [ ] Check missing values.
- [ ] Check leakage.
- [ ] Build time split.
- [ ] Train Logistic Regression.
- [ ] Train Random Forest.
- [ ] Train XGBoost.
- [ ] Evaluate ML metrics.
- [ ] Evaluate trading metrics.
- [ ] Run walk-forward.
- [ ] Analyze SHAP.
- [ ] Save model metadata.
- [ ] Export ONNX.
- [ ] Run parity test.

## Testing

- [ ] Baseline backtest.
- [ ] Shadow backtest.
- [ ] Threshold backtest.
- [ ] Walk-forward test.
- [ ] Rejected candidate audit.
- [ ] Demo forward test.
- [ ] Data drift monitoring.

---

# 33. Non-Negotiable Rules

1. Jangan menggunakan random split untuk data trading.
2. Jangan memasukkan data setelah entry sebagai feature.
3. Jangan retrain setelah satu trade.
4. Jangan mengganti model aktif tanpa challenger evaluation.
5. Jangan mengubah strategi baseline saat dataset sedang dikumpulkan.
6. Jangan memakai win rate sebagai satu-satunya metrik.
7. Jangan menggunakan model recovery yang sama dengan original entry tanpa penelitian terpisah.
8. Jangan mengoptimalkan threshold hanya dari satu periode.
9. Jangan menggunakan screenshot manual sebagai dataset vision utama.
10. Jangan deploy ONNX sebelum parity test berhasil.
11. Jangan biarkan ML membuka order tanpa risk engine.
12. Jangan menganggap feature importance sebagai hubungan sebab-akibat.
13. Jangan menggunakan candle berjalan jika training memakai candle tertutup.
14. Jangan mencampur model training period dengan final test period.
15. Jangan membuat model terlalu kompleks sebelum baseline sederhana terbukti.

---

# 34. Definition of Done Tahap Pertama

Tahap pertama dianggap selesai jika:

- EA menghasilkan dataset candidate yang konsisten.
- Dataset memiliki `setup_id` unik.
- Label entry quality berhasil dihitung.
- Tidak ada data leakage.
- Logistic Regression, Random Forest, dan XGBoost sudah dibandingkan.
- Walk-forward test sudah dilakukan.
- Model menghasilkan probability yang terkalibrasi.
- ONNX berhasil berjalan di Python dan MQL5.
- Parity test berhasil.
- Shadow backtest selesai.
- Filter backtest mengalahkan baseline pada expectancy atau drawdown secara stabil.
- Model berhasil diuji pada demo account tanpa error feature generation.

---

# 35. Final Architecture

```text
MT5 Market Data
    ↓
CCI Trigger Tracker
    ↓
Confirmation State Tracker
    ↓
Candidate Original Entry
    ↓
Feature Snapshot Logger
    ↓
XGBoost ONNX Inference
    ↓
Decision Gate
    ↓
Risk Filters
    ↓
Original Trade
    ↓
Trade Management
    ↓
Outcome Logger
    ↓
Dataset
    ↓
Offline Retraining Pipeline
```

Future architecture:

```text
Rule-Based Entry Engine
        +
XGBoost Entry Quality Model
        +
Vision Market Context Model
        ↓
Decision Fusion
        ↓
Risk Management
        ↓
Execution
```

---

# 36. Current Priority

Prioritas saat ini bukan vision model dan bukan optimasi hyperparameter.

Prioritas saat ini:

```text
1. Bekukan folder32_v1
2. Buat logger yang benar
3. Buat setup_id
4. Buat barrier label
5. Bentuk dataset historical
6. Audit data
7. Train baseline
8. Train XGBoost
9. Walk-forward validation
10. Integrasi ONNX
```

Masalah tersulit proyek ini bukan sintaks training XGBoost.

Masalah tersulit adalah:

- event definition;
- logging;
- labeling;
- leakage prevention;
- time-based validation;
- consistency antara Python dan MQL5.
