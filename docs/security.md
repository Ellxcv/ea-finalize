# Security

- Jangan commit token bot, API key, password, nomor akun, nama broker privat, atau credential VPS.
- Anggap credential yang pernah tertulis dalam source atau log sebagai sudah bocor dan rotasi di
  layanan penerbitnya.
- Jangan commit journal MetaTrader, screenshot dashboard akun, report tester privat, atau file
  konfigurasi yang memuat identitas akun.
- Input rahasia harus dikonfigurasi di lingkungan lokal, bukan diberi default pada source.
- Review hasil pencarian credential dan seluruh staged diff sebelum setiap push.
- Review lisensi custom indicator serta asset pihak ketiga sebelum repository dibuat publik.

Token Telegram yang ditemukan pada material referensi lama sudah dihapus dari nilai default lokal.
Token aslinya tetap harus dicabut melalui BotFather karena penghapusan dari file tidak membatalkan
credential tersebut.
