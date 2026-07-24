# TESTING_STRAT_7 Tuning Analysis

## Objective

Tujuan utama tuning:

1. Meningkatkan kualitas entry strategy original.
2. Mengurangi persentase cycle yang masuk mode recovery.
3. Jika recovery aktif, meningkatkan persentase cycle yang selesai maksimal pada level 2–3.
4. Menjaga expectancy, profit factor, drawdown, dan jumlah peluang trading tetap sehat.
5. Menentukan kondisi ketika compound cukup aman untuk diuji secara bertahap.

Optimasi tidak dianggap berhasil bila win rate naik tetapi net profit, expectancy, atau robustness
turun secara material.

## Current baseline

Baseline pertama berasal dari run 2026-07-22_GOLD-i_M1_default. Statusnya masih candidate karena
kontinuitas tick di sekitar pergantian nama symbol GOLD# menjadi GOLD.i# belum diverifikasi.

| Metric | Baseline | Target awal | Latest accepted |
| --- | ---: | ---: | ---: |
| Total original cycles | 1,441 | Cukup representatif | Pending verification |
| Original win rate | 38.38% | Naik tanpa overfitting | Pending verification |
| Overall profit factor | 1.58 | Tidak memburuk | Pending verification |
| Overall expected payoff | $2.58/trade | Positif dan stabil | Pending verification |
| Recovery entry rate | 60.44% | Turun | Pending verification |
| Recovery selesai <= level 2 | 69.12% | Naik | Pending verification |
| Recovery selesai <= level 3 | 84.16% | Naik | Pending verification |
| Recovery mencapai level 4+ | 15.84% | Turun signifikan | Pending verification |
| Recovery success rate | 98.51% net-positive cycle | Stabil/naik | Pending verification |
| Maximum equity drawdown | $4,115.14 / 90.45% | Turun signifikan | Pending verification |
| Total net profit | $8,818.47 | Positif dan robust | Pending verification |

## Metric definitions

- Original trade: posisi utama yang dibuka oleh sinyal strategy original, sebelum recovery.
- Original win rate: original trades profit dibagi seluruh original trades yang sudah selesai.
- Cycle: satu rangkaian mulai dari entry original sampai selesai tanpa recovery atau seluruh
  recovery selesai/reset.
- Recovery entry rate: cycle yang mengaktifkan recovery dibagi seluruh completed cycle.
- Recovery depth: level recovery tertinggi yang tersentuh dalam satu cycle.
- Recovery <= level 3 rate: recovery cycle yang selesai maksimal di level 3 dibagi seluruh
  recovery cycle.
- Cycle net result: hasil original dan seluruh posisi recovery dalam cycle yang sama.
- Recovery burden: kontribusi waktu, jumlah posisi, volume, dan drawdown recovery terhadap total.

Jika report tidak menyediakan pemisahan ini, catat keterbatasannya dan lampirkan deal history agar
cycle dapat direkonstruksi.

## Test design

Gunakan pembagian data berikut bila datanya mencukupi:

| Dataset | Tujuan | Aturan |
| --- | --- | --- |
| In-sample | Menemukan kandidat | Boleh digunakan untuk tuning |
| Out-of-sample | Menguji generalisasi | Jangan digunakan untuk memilih parameter berulang kali |
| Forward/demo | Menguji kondisi live | Tidak diubah agar cocok dengan hasil |

Pertahankan symbol, timeframe, model tick, spread, commission, deposit, leverage, dan rentang data
saat membandingkan dua variant. Ubah satu kelompok faktor per eksperimen, misalnya filter entry,
exit original, atau recovery trigger.

## Run comparison

Tambahkan satu baris setelah sebuah run dianalisis.

| Run ID | Variant | Original WR | Recovery rate | <= L3 | PF | Max DD | Net profit | Verdict |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 2026-07-22_GOLD-i_M1_default | Default | 38.38% | 60.44% | 84.16% | 1.58 | 90.45% | $8,818.47 | Retest data |
| CCI-study folder 2 | Validity 5 control | 39.02% | 59.71% | 84.07% | 1.56 | 90.45% | $6,219.06 | Reject for DD |
| CCI-study folder 3 | Validity 1 | 47.73% | 50.00% | 90.91% | 2.57 | 2.70% | $310.24 | Reject for inactivity |
| CCI-study folder 4 | Validity 2 | 35.04% | 64.96% | 85.53% | 0.18 | 191.61% | -$8,340.05 | Reject |
| CCI-study folder 5 | Validity 3 | 40.07% | 59.26% | 84.94% | 1.53 | 31.85% | $3,472.01 | Provisional candidate |
| ADX-study folder 6 | CCI3 + ADX bias M1/20 | 39.16% | 60.42% | 84.67% | 1.55 | 32.12% | $2,906.45 | Reject as WR filter |
| ADX-study folder 7 | CCI3 + ADX bias M5/20 | 40.69% | 58.45% | 84.80% | 1.55 | 34.10% | $1,980.02 | Weak improvement |
| ADX-study folder 8 | CCI3 + ADX bias M5/25 | 39.93% | 59.33% | 84.28% | 1.61 | 25.24% | $1,554.60 | Risk-filter candidate |
| ADX-study folder 9 | M5/25, smoothing OFF | 36.00% | 63.00% | 82.54% | 0.31 | 95.72% | -$3,803.64 | Reject; stop-out |
| Original diagnostics folder 17 | Folder 5 + MFE/MAE telemetry | 40.07% | 59.26% | 84.94% | 1.53 | 31.85% | $3,472.01 | Accepted; trades identical |
| Trailing BE folder 18 | Original offset 200 | 44.23%* | 55.77%* | 81.90%* | 0.32 | 170.47% | -$7,752.57 | Reject; stop-out at 33% |
| Trailing BE folder 19 | Original offset 100 | 44.44%* | 55.56%* | 82.61%* | 0.31 | 174.11% | -$7,863.97 | Reject; stop-out at 33% |
| Trailing BE folder 20 | Original offset 50 | 47.47% | 52.53% | 83.01% | 1.52 | 31.88% | $3,427.74 | Provisional accept |
| Entry-context diagnostics folder 21 | Folder 20 + observation telemetry | 47.47% | 52.53% | 83.01% | 1.52 | 31.88% | $3,427.74 | Accepted; no viable threshold |
| Trend-freshness diagnostics folder 22 | Folder 21 + observation telemetry | 47.47% | 52.53% | 83.01% | 1.52 | 31.88% | $3,427.74 | Accepted; no viable threshold |
| CCI-progression diagnostics folder 23 | Folder 22 + observation telemetry | 47.47% | 52.53% | 83.01% | 1.52 | 31.88% | $3,427.74 | Accepted; overshoot candidate |
| Signal-confirmation diagnostics folder 24 | Folder 23 + signal-time alignment | 47.47% | 52.53% | 83.01% | 1.52 | 31.88% | $3,427.74 | Accepted; mask-5 candidate |
| Late-confirmation guard folder 25 | Symmetric exact mask-5 guard | 48.58% | 51.42% | 84.93% | 1.62 | 22.81% | $3,163.68 | Provisional accept |
| Market-structure diagnostics folder 26 | Folder 25 + M1 pivot S/R telemetry | 48.58% | 51.42% | 84.93% | 1.62 | 22.81% | $3,163.68 | Accepted telemetry; reject M1 S/R guard |
| M5 market-structure diagnostics folder 27 | Folder 26 with pivot S/R on M5 | 48.58% | 51.42% | 84.93% | 1.62 | 22.81% | $3,163.68 | Reject M5 and M1+M5 S/R guard |
| Indicator ablation folder 28 | HiLo OFF, guard OFF | 47.76%* | 52.24%* | 83.71%* | 0.72 | 97.82% | -$3,823.28 | Reject; stop-out at 84% |
| Indicator ablation folder 29 | PSAR OFF, guard OFF | 48.02% | 51.98% | 83.23% | 1.56 | 31.53% | $3,712.23 | Viable but no material depth gain |
| Indicator ablation folder 30 | SuperTrend M1 OFF, guard OFF | 44.64%* | 55.36%* | 79.28%* | 0.66 | 105.40% | -$4,370.69 | Reject; stop-out at 42% |
| Indicator ablation folder 31 | SuperTrend M5 OFF, guard OFF | 37.10%* | 62.90%* | N/A | 0.14 | 108.88% | -$4,384.10 | Reject; stop-out at 6% |

`*` Periode parsial akibat stop-out; nilai tidak boleh dipakai sebagai full-period comparison.

## Daily consistency requirement

Daily profit tidak boleh dinilai dari realized balance saja. Grid recovery dapat membuat balance
terlihat naik setiap hari sambil menyimpan floating drawdown besar. Daily scorecard berikut harus
dipakai bersama:

| Metric | Initial requirement |
| --- | ---: |
| Active trading weekdays | >= 80% |
| Positive realized-P/L weekdays | >= 75% |
| Losing weekdays | Serendah mungkin, tetapi tidak disembunyikan floating loss |
| Maximum intraday equity DD | Harus ditentukan sebelum compound |
| Recovery carried overnight | Harus diukur dan dibatasi |
| Recovery depth <= level 3 | Target utama |
| Stop-out / forced liquidation | 0 |

Pada periode 2026-01-04 sampai 2026-05-02:

| Variant | Active days | Positive days | No-trade days | Avg active-day P/L | Median | Max no-trade streak |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Validity 5 | 84/85 | 84/85 | 1 | $74.04 | $68.50 | 1 weekday |
| Validity 1 | 36/85 | 35/85 | 49 | $8.62 | $6.29 | 7 weekdays |
| Validity 2 | 28/85 | 27/85 | 57 | -$297.86 | $26.56 | 56 weekdays |
| Validity 3 | 84/85 | 84/85 | 1 | $41.33 | $36.83 | 1 weekday |

Validity 5 dan 3 memenuhi frekuensi realized daily profit, tetapi belum memenuhi safety karena
masih mencapai level 10. Validity 1 terlalu jarang memberi kesempatan. Validity 2 mengalami
stop-out pada 2026-02-12 dan tidak dapat dianggap selesai menjalankan periode test.

## Indicator and entry diagnosis

### 1. CCI is the highest-sensitivity component

Mengubah satu-satunya parameter CCI signal validity menghasilkan hasil dari profit factor 2.57
dengan sangat sedikit trade sampai kerugian -$8,340. Ini membuktikan timing sinyal CCI adalah
bottleneck utama, bukan sekadar parameter recovery.

CCI custom menghasilkan empat tipe sinyal: strong buy, buy, strong sell, dan sell. Fungsi
GetCCISignal mengembalikan signal type, tetapi entry utama hanya memakai nilai boolean dan
mengabaikan perbedaan strong/normal. Strong counter-trend cross saat CCI berada di luar +/-100
diperlakukan sama dengan normal cross. Ini perlu dibuat dapat dipilih dan dianalisis terpisah.

Audit dependency sebelum folder 23 menemukan bahwa source eksternal `cciCustomFix.mq5` yang
terpasang memiliki ekspresi cross yang membandingkan buffer dengan dirinya sendiri, sementara EX5
yang dipakai backtest tetap menghasilkan signal. Source dan binary kemungkinan tidak sinkron.
Jangan compile ulang atau mempublikasikan dependency tersebut sebelum source, binary, dan lisensi
direkonsiliasi. Folder 23 diikat ke hash source/EX5 yang dicatat pada record run dan membaca handle
EX5 yang sama dengan entry EA.

### 2. Signal-time mismatch

CCI dapat berasal dari satu sampai beberapa candle sebelumnya, sedangkan HiLo, PSAR, SuperTrend,
dan SuperTrend MTF dibaca pada candle terakhir. Artinya filter tidak membuktikan bahwa kondisi trend
yang sama berlaku pada saat CCI signal muncul. Validity 3 lebih aktif daripada validity 1, tetapi
masih dapat menerima signal yang sudah berubah konteks.

### 3. Correlated lagging filters

HiLo, PSAR, SuperTrend M1, dan SuperTrend M5 semuanya membaca trend state berbasis harga. Empat
konfirmasi yang berkorelasi tidak otomatis memberi empat sumber informasi independen. Semuanya
dapat tetap bullish pada fase awal reversal tajam, lalu BUY CCI menangkap falling knife.

### 4. Missing impulse and execution guards

Entry tidak memiliki filter khusus untuk:

- ukuran candle relatif terhadap ATR;
- perubahan harga beberapa bar yang terlalu ekstrem;
- spread maksimum;
- jarak harga dari trend mean/EMA;
- perubahan regime volatility.

Kegagalan validity 2 pada 2026-02-12 menunjukkan BUY recovery bertambah dari level 1 ke 10 hanya
sekitar 12 menit saat harga jatuh cepat, lalu akun stop-out. Filter impulse/ATR lebih langsung
menargetkan kejadian ini daripada menambah trend overlay lain.

Sebelum menambahkan filter tersebut, folder 17 harus mengukur excursion setiap original trade.
Fokus analisis berikutnya:

1. Berapa banyak original loser yang sempat mencapai MFE cukup besar sebelum berbalik.
2. Apakah loser dengan MFE rendah terkonsentrasi pada ATR/range candle atau spread tertentu.
3. Apakah distribusi MFE/MAE berbeda menurut signal age, tipe CCI, sisi BUY/SELL, dan jam entry.
4. Apakah exit original yang berbeda berpotensi menyelamatkan trade tanpa mengurangi winner.

Filter atau aturan breakeven belum boleh diterapkan dari telemetry ini. Folder 17 adalah
eksperimen observasi; history trade harus identik dengan control folder 5.

Folder 17 lulus acceptance check: 594 pasangan original OPEN/CLOSE, `DataErrors=0`,
`ActiveRemaining=0`, dan seluruh 5,565 baris trading sama dengan folder 5 setelah komentar
telemetry diabaikan. Winner berjumlah 238, loser 352, dan neutral 4.

Entry ATR, single-candle range, range/ATR, dan spread hampir identik antara winner dan loser.
Tidak ada threshold monoton yang mendukung impulse atau spread guard langsung dari fitur tersebut.
Namun, 48 loser telah mencapai MFE minimal 500 points dan akhirnya rugi maksimal $1.01. Semua
cycle ini berhenti pada recovery L1–L3. Breakeven floor pada trailing original layak diuji untuk
mengurangi recovery dangkal, tetapi tidak dianggap sebagai solusi bagi 53 cycle recovery L4+.

Folder 21 menguji konteks khusus 53 cycle L4+ setelah offset 50 diterapkan. Trading history folder
20 dan 21 identik, seluruh 594 context record valid, dan error diagnostics nol. Median
`Impulse3ATR`, `Impulse5ATR`, `DistanceEMAATR`, serta `SignalDriftATR` antara winner, recovery
L1-L3, dan L4+ sangat overlap. AUC L4+ versus winner hanya 0.507-0.549.

Tidak ada threshold satu-feature yang mampu menolak minimal 20% L4+ sambil membatasi winner yang
ikut tertolak maksimal 10%. Pada batas winner 10%, hasil terbaik hanya menangkap 5-6 dari 53 L4+
(9.4%-11.3%). Hasil ini juga tidak stabil ketika Januari-Februari dipisahkan dari Maret-Mei.
Karena itu, jangan tambahkan impulse, EMA-distance, atau signal-drift guard dari run ini.

Diagnosis berikutnya beralih dari magnitude harga ke struktur/transisi: usia sejak setiap trend
filter berubah arah, slope trend direction-normalized, perubahan state CCI dari signal ke entry,
posisi dalam recent range, dan perubahan regime volatilitas. Kelompok pertama yang diukur adalah
trend-freshness dan slope; tetap observation-only.

Folder 22 juga mereproduksi control secara exact: preset sama, 5,381 report-history rows identik,
594 context record valid, dan seluruh integrity counter nol. HiLo age memiliki median satu bar pada
winner, L1-L3, dan L4+. SuperTrend MTF age memiliki median sembilan bar pada ketiga grup. EMA slope
L4+ sedikit lebih positif daripada winner, berlawanan dengan hipotesis trend melemah.

AUC keenam feature hanya 0.525-0.565. Dengan winner rejection dibatasi 10%, hasil terbaik adalah
`EMASlope10ATR >= 0.985`, tetapi hanya menangkap 7 dari 53 L4+ (13.2%) sambil menolak 28 winner
(9.9%). Tidak ada threshold tunggal atau kombinasi dua kondisi AND/OR yang memenuhi target pada
Januari-Februari dan Maret-Mei. Trend-age dan EMA-slope guard tidak diteruskan.

Diagnosis berikutnya memprioritaskan CCI progression dari candle signal ke entry. Recent-range
position dan volatility regime tetap menjadi hipotesis setelah konteks CCI selesai diuji.

Folder 23 mereproduksi control secara exact dan seluruh 594 CCI context valid. Momentum cross
masih bertahan pada 593 entry; satu cross yang hilang hanya mencapai recovery L1-L3. Dengan
demikian, stale signal bukan berupa cross yang sudah berbalik.

Pola berbeda muncul ketika smoothed CI masih ekstrem pada signal tetapi raw CCI sudah bergerak
terlalu jauh ke arah posisi saat entry. Rule direction-normalized `-Direction × CISignal >= 80`
dan `Direction × CCIEntry >= 110` menandai 12/53 L4+ (22.6%), 27/282 winner (9.6%), dan 25/259
L1-L3 (9.7%). Rule tetap memenuhi screen pada Januari-Februari dan Maret-Mei.

Separation terkonsentrasi pada BUY: 11/33 BUY L4+ versus 16/166 BUY winner ditandai. Pada SELL,
hanya 1/20 L4+ versus 11/116 winner, sehingga symmetric rule membawa false rejection yang tidak
produktif. Kandidat perlu diuji sebagai BUY_ONLY dan BOTH secara default-off. Threshold tidak boleh
dituning lagi pada dataset ini, dan variant terpilih harus lolos out-of-sample.

Namun, sekitar 94% signal yang akhirnya entry sudah berumur dua atau tiga bar. HiLo, PSAR,
SuperTrend M1, dan SuperTrend M5 semuanya harus searah pada bar entry, sehingga pola overshoot
dapat merupakan gejala confirmation stack yang terlambat, bukan akar masalah CCI. Implementasi
guard 80/110 ditahan. Folder 24 lebih dahulu mencatat alignment setiap filter pada saat candle CCI
selesai dan pada saat entry tanpa mengubah keputusan trading.

Folder 24 mereproduksi folder 23 secara exact dan seluruh 594 confirmation context valid. HiLo
terlambat pada 96.2% L4+ tetapi juga 87.9% winner, sehingga terlalu umum untuk dijadikan filter
sendiri. PSAR lebih sering terlambat pada winner daripada L4+, sedangkan SuperTrend M5 tidak
terlambat pada satu pun L4+.

Exact `LateConfirmMask=5` menjadi kandidat terdekat: HiLo dan SuperTrend M1 berlawanan pada
signal-close sementara PSAR dan SuperTrend M5 sudah aligned. Pola ini menandai 14/53 L4+ (26.4%),
29/282 winner (10.3%), dan 34/259 L1-L3 (13.1%). Hasil stabil pada time split: 25.0% versus 10.5%
di Januari-Februari dan 28.0% versus 10.1% di Maret-Mei. Rule meleset tipis dari batas winner 10%
dan dipilih hanya sebagai eksperimen default-off, bukan filter final.

Pada 13/14 L4+ bertanda mask 5, HiLo dan SuperTrend M1 berubah bersamaan pada candle terakhir
sebelum entry. Karena mematikan salah satunya masih menyisakan filter lain sebagai gate, ablation
satu filter tidak diprioritaskan. Guard harus berlaku simetris untuk BUY dan SELL sesuai tujuan EA;
variant direction-only tidak digunakan.

### 5. ADX directional bias reduces exposure, not the original-entry problem

ADX M1/20 menurunkan original win rate menjadi 39.16% dan menaikkan recovery rate menjadi 60.42%.
ADX M5/20 hanya menaikkan original win rate 0.62 percentage point, dengan relative equity DD yang
justru naik menjadi 34.10%. ADX M5/25 menurunkan relative equity DD menjadi 25.24% dan recovery
overnight menjadi 1 cycle, tetapi original win rate tetap 39.93% dan L4+ tetap 15.72%.

Dengan demikian, ADX M5/25 boleh dipertahankan sebagai kandidat pengurang exposure. ADX belum
terbukti mampu memilih original entry dengan lebih akurat. Seluruh variant masih mencapai recovery
level 10.

Test smoothing OFF pada folder 9 memperburuk original win rate menjadi 36.00% dan mengulang
falling-knife BUY tanggal 2026-02-12 17:44. Recovery mencapai L10 dalam sekitar 30 menit dan cycle
kehilangan sekitar $4,387.23. Balance tersisa $196.36 sehingga report tidak menyelesaikan periode
secara normal. ADX tuning dihentikan; smoothing tidak boleh dinonaktifkan pada kandidat ini.

### 6. Single-filter ablation rejects removing the trend gates

Folders 28–31 mematikan satu confirmation filter per run dengan late-confirmation guard OFF.
HiLo OFF, SuperTrend M1 OFF, dan SuperTrend M5 OFF masing-masing berakhir stop-out. SuperTrend M5
memberi kerusakan paling cepat: original WR hanya 37.10% dan akun berhenti pada 2026-01-12.
SuperTrend M1 OFF berhenti pada 2026-02-23 dengan WR 44.64%, sedangkan HiLo OFF berhenti pada
2026-04-14 meskipun WR parsial 47.76%.

Ketiga final cycle berasal dari original SELL yang tidak ada pada control folder 24, lalu recovery
bertambah sampai L10. Ini menunjukkan filter tersebut bukan sekadar duplikasi mekanis: masing-masing
mencegah setidaknya satu setup yang fatal pada dataset ini.

PSAR OFF adalah satu-satunya ablation yang menyelesaikan periode. Dibanding folder 24, WR naik
47.47% menjadi 48.02%, recovery turun 52.53% menjadi 51.98%, PF naik 1.52 menjadi 1.56, dan net
naik $3,427.74 menjadi $3,712.23. Namun L4+ absolut naik 53 menjadi 55, persentase recovery yang
selesai maksimal L3 hanya naik 83.01% menjadi 83.23%, dan maximum depth tetap L10.

Perbaikan PSAR OFF terlalu kecil dan tidak menargetkan recovery depth. Folder 25 dengan semua
filter serta mask-5 guard tetap lebih sesuai objective: WR 48.58%, recovery 51.42%, L4+ 41,
PF 1.62, dan equity DD 22.81%. Karena itu, pertahankan seluruh confirmation stack dan mask-5 guard;
jangan hapus PSAR dari candidate saat ini.

## Baseline findings

### Recovery distribution

| Maximum depth | Cycle | Percent of recovery |
| ---: | ---: | ---: |
| Level 1 | 348 | 39.95% |
| Level 2 | 254 | 29.16% |
| Level 3 | 131 | 15.04% |
| Level 4 | 67 | 7.69% |
| Level 5 | 28 | 3.21% |
| Level 6 | 16 | 1.84% |
| Level 7 | 10 | 1.15% |
| Level 8 | 7 | 0.80% |
| Level 9 | 2 | 0.23% |
| Level 10 | 8 | 0.92% |

Original BUY dan SELL hampir sama lemah: BUY original win rate 38.29% dengan recovery rate 60.72%,
sedangkan SELL original win rate 38.49% dengan recovery rate 60.09%. Masalah awal tidak tampak
terisolasi pada satu arah.

Jam server 10, 13, dan 19 menunjukkan original win rate terendah pada baseline, sedangkan jam 20
tertinggi. Temuan ini baru hipotesis; filter jam tidak boleh diterapkan sebelum diuji pada
out-of-sample dan dikonfirmasi bahwa perbedaan bukan akibat regime atau kualitas tick.

### Extreme drawdown candidate

Report mencatat maximum equity drawdown $4,115.14 atau 90.45%, sementara maximum balance drawdown
hanya $527.22 atau 10.40%. Grafik menunjukkan kejadian ini sebagai floating drawdown singkat.

Cycle kandidat terkuat dimulai 2026-01-16 17:05 server time:

- original BUY 0.01 pada 4616.35 ditutup -$6.29;
- recovery bertambah sampai 10 level dan maximum single lot 0.38;
- basket ditutup 2026-01-16 18:01;
- hasil bersih seluruh cycle hanya sekitar +$0.76.

Preset membolehkan kondisi tersebut karena RecoveryGridMaxLevels=10, sedangkan MaxRecoverySteps,
MaxRecoveryLot, RecoveryMaxDrawdown, dan MaxRecoveryPositions semuanya nol/tanpa batas aktif.
Anomali data dapat memperparah excursion, tetapi kedalaman dan exposure tersebut juga merupakan
konsekuensi langsung konfigurasi risiko.

### Data-integrity status

Run memakai GOLD.i#, periode 2026-01-04 sampai 2026-06-27, dan melaporkan 99% real ticks. Nilai 99%
tidak membuktikan bahwa tidak ada gap, spike, perubahan spread, atau discontinuity akibat migrasi
GOLD# ke GOLD.i#.

Sebelum tuning parameter, verifikasi:

1. tanggal efektif pergantian symbol dari broker;
2. tick/bar 2026-01-16 17:00–18:05, termasuk spread dan gap;
3. rerun pendek periode 2026-01-12–2026-01-20 pada history bersih;
4. hasil symbol lama dan baru pada periode overlap jika keduanya tersedia;
5. perbandingan dengan journal/live observation yang pernah disimpan.

## Diagnostic questions

Untuk setiap run, jawab:

1. Kondisi market apa yang paling sering menghasilkan loss original?
2. Apakah loss terkonsentrasi pada session, jam, spread, arah, atau regime tertentu?
3. Apakah filter tambahan menolak loss lebih banyak daripada winner?
4. Apakah entry terlambat sehingga reward-to-risk memburuk?
5. Apakah exit original terlalu ketat atau terlalu lambat?
6. Berapa distribusi recovery depth L1, L2, L3, dan L4+?
7. Recovery dalam paling sering berasal dari setup original yang mana?
8. Apakah hasil tetap masuk akal pada out-of-sample dan periode market berbeda?

## Experiment queue

| Priority | Hypothesis | Change scope | Success criterion | Status |
| ---: | --- | --- | --- | --- |
| 1 | CCI validity 3 memberi kompromi aktivitas/kualitas terbaik | Jadikan folder 5 control berikutnya | Daily coverage tetap 80%+ | Selected |
| 2 | Directional trend strength dapat menolak falling knife | CCI3 + ADX_WITH_BIAS, M1/M5 | Original WR naik, recovery turun, active days >=80% | Tested; weak |
| 3 | ADX smoothing 14 bar terlalu lambat | M5/25 dengan smoothing OFF | WR/recovery membaik tanpa DD/coverage rusak | Rejected; stop-out |
| 4 | Strong dan normal CCI memiliki risiko berbeda | Test BOTH, NORMAL_ONLY, STRONG_ONLY | Identifikasi tipe dengan expectancy terbaik | Implemented; folders 10–12 next |
| 5 | Impulse beberapa bar memicu deep recovery | Tambahkan directional impulse + distance-from-mean telemetry | Temukan separator loser L4+ tanpa merusak coverage | Rejected; no separator |
| 6 | Trailing breakeven floor mencegah recovery dari loss kecil | Uji offset original 50, 100, dan 200 points | Recovery turun; net/PF/DD tidak rusak; L4+ absolut tidak naik | Offset 50 provisional; 100/200 rejected |
| 7 | Risk control tidak membatasi deep recovery | Cap recovery diuji setelah entry membaik | Tidak ada stop-out; depth dan DD terkendali | Pending |
| 8 | Deep recovery berasal dari trend alignment yang stale atau melemah | Tambahkan trend-age dan direction-normalized slope telemetry | Tolak >=20% L4+ dengan <=10% winner pada dua bagian waktu | Rejected; no separator |
| 9 | Momentum CCI berubah antara candle signal dan entry | Tambahkan CCI signal/entry value dan direction-normalized delta telemetry | Tolak >=20% L4+ dengan <=10% winner pada dua bagian waktu | Candidate found |
| 10 | CCI reversal sudah overshoot sebelum entry | Guard `CI magnitude >=80 && directional CCI entry >=110` | L4+ turun; WR/recovery membaik tanpa merusak PF/DD/coverage | Paused; may mask late confirmation |
| 11 | Salah satu trend filter baru mengonfirmasi setelah signal CCI | Log alignment HiLo, PSAR, ST M1, dan ST M5 pada signal-close versus entry | Identifikasi late confirmer yang terkonsentrasi pada L4+ dan stabil pada time split | Mask 5 candidate found |
| 12 | HiLo+ST M1 simultaneous late flip menghasilkan chase entry | Block exact mask 5 secara simetris, default-off | WR naik, recovery dan L4+ turun, coverage/PF/net/DD terjaga | Implemented; folder 25 next |
| 13 | Entry terlalu dekat structural S/R meningkatkan deep recovery | Log confirmed-pivot S/R M1/M5, room ATR, trend, swing, dan level age | Tolak >=20% L4+ dengan <=10% winner pada dua bagian waktu | Rejected on M1, M5, and combined |
| 14 | Salah satu confirmation filter redundan dan dapat dihapus | Matikan HiLo, PSAR, ST M1, atau ST M5 satu per run dengan guard OFF | WR/recovery/L4+ membaik tanpa stop-out atau DD rusak | Rejected; PSAR OFF only marginal |
| 15 | Initial SL berbasis volatilitas mengurangi original loss yang terlalu cepat | Tambahkan mode candle-anchored ATR 14 RMA × 1.4, default-off | WR/recovery membaik tanpa loss size, L4+, PF, atau DD memburuk | Inconclusive; folder 32 changed multiple groups |
| 16 | Entry-state strength/distance menambah signal prediktif | Tambahkan 15 feature ADX/DI, CCI velocity, ATR, dan indicator geometry | Tolak >=20% L4+ dengan <=10% winner; WR/recovery membaik | Rejected; folders 43–44 only reach 11.29% L4+ |
| 17 | Barrier label terlalu tidak langsung untuk tujuan bisnis | Challenger target NO_RECOVERY dan L4_PLUS dengan walk-forward validation-only threshold | WR +3 pp, recovery -10%, L4+ rejection >=20%, winner rejection <=10% per fold | Rejected; no fold passes all gates |
| 18 | Conditional L4 target dan XGBoost dapat menghilangkan deep recovery walau winner rejection tinggi | Train L4+ hanya versus L1-L3; hard gate zero allowed L4+, retained 50%, active days 80% | Nol L4+ pada setiap fold dengan aktivitas terjaga | Rejected on v2 features; XGBoost still allows 28/62 L4+ |

## Decision log

| Date | Run ID | Decision | Reason | Next action |
| --- | --- | --- | --- | --- |
| 2026-07-22 | 2026-07-22_GOLD-i_M1_default | Retest | Equity DD 90.45% dan migrasi symbol belum tervalidasi | Audit tick dan rerun window Januari |
| 2026-07-23 | CCI validity study 2–5 | Use validity 3 as provisional control | Validity 1 inactive; validity 2 stop-out; validity 5 excessive DD | Test ADX directional bias |
| 2026-07-23 | ADX directional-bias study 5–8 | Do not accept ADX as WR solution | M1 worsened WR; M5 improvements were not material | Test M5/25 without smoothing once, then split CCI signal types |
| 2026-07-23 | ADX smoothing-off folder 9 | Stop ADX parameter tuning | WR 36.00%, recovery 63.00%, and account nearly depleted on 2026-02-12 | Implement CCI signal-type separation, then impulse guard |
| 2026-07-23 | CCI signal-type implementation | Prepare folders 10–12 | BOTH remains default; normal/strong receive separate telemetry | Backtest BOTH, NORMAL_ONLY, STRONG_ONLY |
| 2026-07-23 | Original diagnostics folder 17 | Accept telemetry; do not add ATR/range/spread entry guard | Trades match control; entry features do not separate outcomes; 48 tiny losses reached MFE 500+ | Test original trailing breakeven offsets 50 and 100 |
| 2026-07-23 | Trailing BE folders 18–20 | Keep offset 50 as provisional candidate; reject 100/200 | Offset 50 raises original WR to 47.47% with similar net/DD; larger offsets stop out during February shock | Stop offset tuning; diagnose entry context of 53 L4+ cycles |
| 2026-07-23 | Entry-context diagnostics folder 21 | Do not add impulse/EMA-distance entry guard | History reproduced exactly; no feature reaches the 20% L4+ / 10% winner screen and none survives the time split | Instrument trend freshness and slope next |
| 2026-07-23 | Trend-freshness diagnostics implementation | Prepare folder 22 as observation-only | Log signed age for four trend filters and direction-normalized EMA slope without changing decisions | Reproduce folder 21, then screen L4+ separation |
| 2026-07-23 | Trend-freshness diagnostics folder 22 | Do not add trend-age or EMA-slope guard | History reproduced exactly; no single or paired rule reaches the screen on both time splits | Instrument CCI progression from signal to entry |
| 2026-07-23 | CCI-progression diagnostics implementation | Prepare folder 23 as observation-only | Read raw CCI and smoothed CI from the same custom-indicator handle at signal and entry | Reproduce folder 22, then screen CCI persistence |
| 2026-07-23 | CCI-progression diagnostics folder 23 | Pause overshoot guard; inspect confirmation stack first | 80/110 pair is BUY-heavy and may only capture entry delayed by four simultaneous trend filters | Add signal-time versus entry-time filter telemetry |
| 2026-07-23 | Signal-time confirmation diagnostics implementation | Prepare folder 24 as observation-only | Preserve folder 23 decisions while identifying which filter changes from misaligned at CCI signal-close to aligned at entry | Reproduce folder 23, then compare winner, L1-L3, and L4+ masks |
| 2026-07-23 | Signal-time confirmation diagnostics folder 24 | Test exact mask 5; do not accept it yet | 14/53 L4+ versus 29/282 winner, stable across time, with simultaneous HiLo+ST M1 final-bar flips on 13/14 deep cases | Implement one symmetric OFF/ON guard |
| 2026-07-23 | Late-confirmation guard implementation | Prepare folder 25 | Apply exact mask 5 equally to BUY and SELL; leave CCI overshoot and recovery unchanged | Backtest against folder 24 control |
| 2026-07-23 | Late-confirmation guard folder 25 | Keep mask-5 guard as provisional candidate | WR, PF, L4+, and DD improve; net profit and average daily profit decline, so compound readiness is not established | Diagnose remaining 41 L4+ with market structure |
| 2026-07-23 | Market-structure diagnostics folder 26 | Do not add an M1 S/R entry guard | Room, trend, swing, and level age overlap winner; no stable rule passes 20% L4+ / 10% winner screen | Run one M5 structure snapshot and combine it offline with folder 26 |
| 2026-07-23 | M5 market-structure diagnostics folder 27 | Close S/R as an entry-guard hypothesis | M5 and every screened M1+M5 pair still fail the L4+ catch / winner-loss screen | Move to candle/volatility regime or session-transition diagnostics |
| 2026-07-23 | Indicator ablation folders 28–31 | Keep all four confirmation filters | HiLo/ST M1/ST M5 OFF stop out; PSAR OFF gives only marginal aggregate gain and L4+ rises to 55 | Implement optional ATR initial SL without changing entry |
| 2026-07-24 | ATR initial-stop implementation | Prepare fixed regression and one ATR experiment | Default remains fixed; ATR uses closed-candle high/low plus RMA 14 × 1.4 and actual SL distance for dynamic lot | Backtest folders 32–33 |
| 2026-07-24 | Folder 32 preset audit | Do not interpret as isolated ATR test; freeze as `folder32_v1` ML baseline | Actual preset used ATR SL plus different entry, session, trailing, and recovery settings, so causality versus folder 25 is unavailable | Use exact manifest for observation-only ML dataset logger |
| 2026-07-24 | Entry-state v2 folders 43–44 | Do not freeze model or open final OOS | Audit passes 1,080 candidates, but AUC remains random; best L4+ rejection 11.29% and original WR/recovery do not improve | Review direct business-label challenger |

| 2026-07-24 | Dual business-target challenger folders 43-44 | Reject both pairs; keep runtime ML_OFF and final OOS sealed | NO_RECOVERY AUC improves to 0.6075-0.6220, but L4-risk AUC is 0.4576-0.4959 and no fold passes all gates | Gather independent development data or a new depth-specific feature hypothesis |
| 2026-07-24 | Conditional zero-L4 XGBoost challenger | Keep XGBoost as development leader but reject runtime promotion | AUC improves to 0.6345/0.5529 and recovery falls 17.66%, but 28/62 evaluation L4+ remain and no validation fold finds a feasible zero-L4 threshold | Add compact volatility, trend durability, momentum, and structure feature v3 using the same quality dataset |

## Compound readiness gate

Compound belum dianggap siap hanya karena satu backtest menghasilkan profit tinggi. Kandidat harus:

- lolos compile dan test tanpa error;
- memiliki expectancy positif dan drawdown yang dapat diterima;
- menunjukkan recovery entry rate serta kedalaman recovery yang membaik;
- tidak bergantung pada satu bulan, session, atau regime;
- lolos out-of-sample dan forward test;
- memakai kenaikan risiko bertahap dengan batas drawdown dan kill switch yang jelas.
