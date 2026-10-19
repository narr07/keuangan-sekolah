import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/transaction_model.dart';
import '../models/tx_category.dart';
import '../theme/app_colors.dart';
import '../widgets/form_widgets.dart';
import '../widgets/indonesian_currency_formatter.dart';

/// Halaman daftar & input transaksi, dipakai untuk Pemasukan dan Pengeluaran.
class TransactionScreen extends StatefulWidget {
  /// [TxType.income] atau [TxType.expense].
  final String type;

  const TransactionScreen({super.key, required this.type});

  @override
  State<TransactionScreen> createState() => TransactionScreenState();
}

class TransactionScreenState extends State<TransactionScreen> {
  static const _allFilter = 'Semua';

  final _dbHelper = DatabaseHelper.instance;
  final _currencyFormat = NumberFormat('#,##0', 'id_ID');

  int _year = DateTime.now().year;
  List<TransactionModel> _items = [];
  bool _isLoading = true;
  String _selectedFilter = _allFilter;

  bool get _isIncome => widget.type == TxType.income;
  String get _noun => _isIncome ? 'Pemasukan' : 'Pengeluaran';
  List<TxCategory> get _categories => TxCategory.forType(widget.type);
  TxCategory _category(String name) => TxCategory.lookup(widget.type, name);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void reload() => _loadData();

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final year = (await _dbHelper.getSettings()).activeYear;
    final items = await _dbHelper.getTransactions(
      year: year,
      type: widget.type,
    );
    if (!mounted) return;
    setState(() {
      _year = year;
      _items = items;
      _isLoading = false;
    });
  }

  List<TransactionModel> get _filteredItems {
    if (_selectedFilter == _allFilter) return _items;
    return _items
        .where((t) => _category(t.category).label == _selectedFilter)
        .toList();
  }

  String _formatCurrency(double amount) =>
      'Rp ${_currencyFormat.format(amount.toInt())}';

  /// Tanggal awal form: hari ini, atau akhir tahun bila melihat tahun lampau.
  DateTime _defaultDate() {
    final now = DateTime.now();
    return _year >= now.year ? now : DateTime(_year, 12, 31);
  }

  void _showLinkedInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Pemasukan ini berasal dari pencairan BOS. Ubah atau hapus dari halaman BOS.',
        ),
      ),
    );
  }

  // ==================== ADD / EDIT ====================

  Future<void> _showAddDialog() async {
    final selected = await showModalBottomSheet<TxCategory>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 20),
            Text(
              'Pilih Kategori $_noun',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isIncome
                  ? 'Dana BOS otomatis masuk dari halaman BOS.\nPilih kategori lain untuk input manual.'
                  : 'Pilih kategori untuk mencatat pengeluaran.',
              style: const TextStyle(fontSize: 13, color: Colors.black45),
            ),
            const SizedBox(height: 20),
            for (final c in _categories) ...[
              _buildCategoryOption(ctx, c),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );

    if (selected != null && mounted) _showInputForm(selected, null);
  }

  Widget _buildCategoryOption(BuildContext ctx, TxCategory c) {
    final disabled = c.automatic;
    final color = disabled ? Colors.grey.shade400 : c.color;
    return GestureDetector(
      onTap: disabled ? null : () => Navigator.pop(ctx, c),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: disabled
                ? Colors.grey.shade200
                : c.color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: disabled
                    ? Colors.grey.shade200
                    : c.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(c.icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: disabled
                          ? Colors.grey.shade400
                          : AppColors.textDark,
                    ),
                  ),
                  Text(
                    c.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: disabled ? Colors.grey.shade400 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            if (disabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Otomatis',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black38,
                  ),
                ),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  /// Pengeluaran yang melebihi saldo sumber dananya perlu dikonfirmasi.
  /// Mengembalikan `true` bila boleh disimpan.
  Future<bool> _confirmBalance(
    BuildContext ctx,
    String fundSource,
    double amount,
    int? editedId,
  ) async {
    final balance = await _dbHelper.getFundBalance(
      fundSource,
      excludeId: editedId,
    );
    if (amount <= balance || !ctx.mounted) return true;

    final label = FundSource.label(fundSource);
    final proceed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Text('Saldo $label tidak cukup'),
        content: Text(
          'Sisa saldo $label saat ini ${_formatCurrency(balance)}, '
          'sedangkan pengeluaran ini ${_formatCurrency(amount)}. '
          'Bila disimpan, saldo $label menjadi minus '
          '${_formatCurrency(amount - balance)}.\n\n'
          'Periksa kembali sumber dananya, atau catat dulu pemasukan/'
          'pencairan yang belum dimasukkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Periksa Lagi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text(
              'Tetap Simpan',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    return proceed == true;
  }

  Future<void> _showInputForm(
    TxCategory category,
    TransactionModel? existing,
  ) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descController = TextEditingController(
      text: existing?.description ?? '',
    );
    var amountText = existing != null
        ? _currencyFormat.format(existing.amount.toInt())
        : '';
    var selectedDate = existing?.date ?? _defaultDate();
    var selectedSource =
        existing?.fundSource ??
        (_isIncome ? FundSource.lainnya : FundSource.bos);
    final isEdit = existing != null;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: category.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        category.icon,
                        color: category.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEdit
                          ? 'Edit ${category.label}'
                          : 'Tambah ${category.label}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const FormLabel('Judul'),
                TextFormField(
                  controller: titleController,
                  decoration: formInputDecoration(
                    _isIncome
                        ? 'Contoh: Sumbangan Alumni'
                        : 'Contoh: Bayar listrik',
                  ),
                ),
                const SizedBox(height: 16),

                // Pemasukan manual selalu Dana Lainnya; Dana BOS masuk
                // lewat pencairan di halaman BOS.
                if (!_isIncome) ...[
                  const FormLabel('Sumber Dana'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final source in FundSource.all)
                        ChoiceChip(
                          label: Text(FundSource.label(source)),
                          selected: selectedSource == source,
                          selectedColor: AppColors.primary.withValues(
                            alpha: 0.15,
                          ),
                          onSelected: (_) =>
                              setModalState(() => selectedSource = source),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                const FormLabel('Jumlah'),
                AmountPickerField(
                  value: amountText,
                  title: 'Jumlah $_noun',
                  accentColor: category.color,
                  onChanged: (v) => setModalState(() => amountText = v),
                ),
                const SizedBox(height: 16),

                const FormLabel('Tanggal'),
                DatePickerField(
                  value: selectedDate,
                  onChanged: (d) => setModalState(() => selectedDate = d),
                ),
                const SizedBox(height: 16),

                const FormLabel('Keterangan (Opsional)'),
                TextFormField(
                  controller: descController,
                  maxLines: 2,
                  decoration: formInputDecoration('Catatan...'),
                ),
                const SizedBox(height: 24),

                SaveButton(
                  label: isEdit ? 'Simpan Perubahan' : 'Simpan $_noun',
                  onPressed: () async {
                    final amount = IndonesianCurrencyFormatter.parse(
                      amountText,
                    );
                    if (amount <= 0 || titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Lengkapi judul dan jumlah'),
                        ),
                      );
                      return;
                    }
                    if (!_isIncome &&
                        !await _confirmBalance(
                          ctx,
                          selectedSource,
                          amount,
                          existing?.id,
                        )) {
                      return;
                    }

                    final description = descController.text.trim();
                    final transaction = TransactionModel(
                      id: existing?.id,
                      title: titleController.text.trim(),
                      // Kategori lama (mis. SPP) dipertahankan saat diedit.
                      category: existing?.category ?? category.name,
                      amount: amount,
                      type: widget.type,
                      date: selectedDate,
                      description: description.isEmpty ? null : description,
                      icon: category.iconName,
                      fundSource: selectedSource,
                    );
                    if (isEdit) {
                      await _dbHelper.updateTransaction(transaction);
                    } else {
                      await _dbHelper.insertTransaction(transaction);
                    }
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == true) _loadData();
  }

  Future<void> _delete(TransactionModel tx) async {
    if (tx.isLinkedToDisbursement) return _showLinkedInfo();
    final ok = await confirmDelete(
      context,
      title: 'Hapus $_noun',
      message: 'Yakin ingin menghapus ${_noun.toLowerCase()} ini?',
    );
    if (ok && tx.id != null) {
      await _dbHelper.deleteTransaction(tx.id!);
      _loadData();
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _isIncome
                                ? Icons.south_west
                                : Icons.outbound_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _noun,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildSummaryCard(),
                        _buildFilterChips(),
                        _buildTransactionList(_filteredItems),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_${widget.type}',
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 6,
        child: const Icon(Icons.add, size: 30, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final total = _items.fold<double>(0, (sum, t) => sum + t.amount);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOTAL ${_noun.toUpperCase()} TAHUN $_year',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatCurrency(total),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tahun Anggaran $_year • ${_items.length} transaksi',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [_allFilter, for (final c in _categories) c.label];
    return SizedBox(
      height: 50,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.1),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                filter,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.black54,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionList(List<TransactionModel> items) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daftar Transaksi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                '${items.length} Transaksi',
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada ${_noun.toLowerCase()}',
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final tx in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTransactionTile(tx, dateFormat),
              ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(TransactionModel tx, DateFormat dateFormat) {
    final c = _category(tx.category);
    final details = [
      dateFormat.format(tx.date),
      tx.categoryLabel,
      if (!_isIncome) FundSource.label(tx.fundSource),
    ].join(' • ');

    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => tx.isLinkedToDisbursement
                ? _showLinkedInfo()
                : _showInputForm(c, tx),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
            borderRadius: BorderRadius.circular(14),
          ),
          SlidableAction(
            onPressed: (_) => _delete(tx),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Hapus',
            borderRadius: BorderRadius.circular(14),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: c.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(c.icon, color: c.color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
            Text(
              '${_isIncome ? '+' : '-'} ${_formatCurrency(tx.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isIncome ? AppColors.emerald600 : AppColors.red500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
