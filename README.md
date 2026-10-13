# BudgetKu Edu

Aplikasi Flutter untuk mencatat keuangan sekolah, terutama dana BOS. Semua data
tersimpan lokal di perangkat (SQLite).

## Fitur

- **Dana BOS**: pagu per semester dan riwayat pencairan. Pencairan berstatus
  *Cair* otomatis tercatat sebagai pemasukan (tertaut lewat `disbursement_id`).
- **Pemasukan & Pengeluaran** dengan kategori dan **sumber dana** (Dana BOS /
  Dana Lainnya).
- **Tahun anggaran**: semua halaman menampilkan data tahun aktif; ganti tahun
  dari Beranda. Sisa saldo tahun lalu terbawa sebagai saldo awal.
- **Laporan** grafik serta ekspor PDF/Excel per tahun anggaran.
- **Backup & pulihkan** seluruh data ke file JSON (Pengaturan, atau saat
  onboarding di HP baru).

## Pengembangan

```bash
flutter pub get
flutter analyze
flutter test
```

## Build rilis Android

Buat `android/key.properties` (jangan di-commit):

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/path/ke/upload-keystore.jks
```

Tanpa file ini, build rilis ditandatangani dengan kunci debug (hanya untuk uji
coba, ditolak Play Store). Simpan cadangan keystore dan password-nya di tempat
aman di luar repo.
