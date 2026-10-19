import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'transaction_model.dart';

/// Kategori transaksi beserta tampilannya.
class TxCategory {
  /// Nilai yang disimpan di kolom `category`.
  final String name;
  final String label;
  final String subtitle;
  final IconData icon;

  /// Nama ikon yang disimpan di kolom `icon` (lihat [iconFromName]).
  final String iconName;
  final Color color;
  final Color background;

  /// Dibuat otomatis oleh aplikasi, tidak bisa dipilih manual.
  final bool automatic;

  const TxCategory({
    required this.name,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconName,
    required this.color,
    required this.background,
    this.automatic = false,
  });

  /// Kategori untuk [type]; elemen terakhir selalu "Lainnya", penampung
  /// kategori yang tidak dikenal (termasuk kategori lama seperti SPP/Gaji).
  static List<TxCategory> forType(String type) =>
      type == TxType.income ? incomeCategories : expenseCategories;

  /// Kategori yang cocok dengan [name], atau "Lainnya" bila tidak dikenal.
  static TxCategory lookup(String type, String name) {
    final list = forType(type);
    return list.firstWhere((c) => c.name == name, orElse: () => list.last);
  }

  static final incomeCategories = [
    TxCategory(
      name: kBosCategory,
      label: 'Dana BOS',
      subtitle: 'Otomatis dari pencairan BOS',
      icon: Icons.account_balance,
      iconName: 'account_balance',
      color: AppColors.primary,
      background: AppColors.primary.withValues(alpha: 0.15),
      automatic: true,
    ),
    TxCategory(
      name: 'Pinjaman',
      label: 'Pinjaman',
      subtitle: 'Pinjaman modal kerja, dll',
      icon: Icons.description,
      iconName: 'description',
      color: Colors.amber.shade600,
      background: Colors.amber.shade50,
    ),
    TxCategory(
      name: 'Sumbangan',
      label: 'Sumbangan',
      subtitle: 'Donasi alumni, wali murid, dll',
      icon: Icons.favorite,
      iconName: 'favorite',
      color: Colors.pink.shade500,
      background: Colors.pink.shade50,
    ),
    const TxCategory(
      name: 'Lainnya',
      label: 'Lainnya',
      subtitle: 'Pemasukan dari sumber lain',
      icon: Icons.savings,
      iconName: 'savings',
      color: AppColors.emerald600,
      background: AppColors.mint,
    ),
  ];

  static final expenseCategories = [
    TxCategory(
      name: 'Operasional',
      label: 'Operasional',
      subtitle: 'Listrik, air, ATK, kebersihan',
      icon: Icons.settings,
      iconName: 'settings',
      color: Colors.blue.shade600,
      background: Colors.blue.shade50,
    ),
    TxCategory(
      name: 'Transport',
      label: 'Transport',
      subtitle: 'Rapat, sosialisasi, transport guru',
      icon: Icons.directions_car,
      iconName: 'directions_car',
      color: Colors.orange.shade600,
      background: Colors.orange.shade50,
    ),
    TxCategory(
      name: 'Sarana',
      label: 'Sarana',
      subtitle: 'Perbaikan & perawatan fasilitas',
      icon: Icons.build,
      iconName: 'build',
      color: Colors.purple.shade600,
      background: Colors.purple.shade50,
    ),
    TxCategory(
      name: 'Lainnya',
      label: 'Lainnya',
      subtitle: 'Pengeluaran lain-lain',
      icon: Icons.receipt,
      iconName: 'receipt',
      color: Colors.red.shade500,
      background: Colors.red.shade50,
    ),
  ];

  /// Ikon dari nama yang tersimpan di kolom `icon`.
  static IconData iconFromName(String iconName) {
    for (final c in [...incomeCategories, ...expenseCategories]) {
      if (c.iconName == iconName) return c.icon;
    }
    return iconName == 'payments' ? Icons.payments : Icons.receipt;
  }
}
