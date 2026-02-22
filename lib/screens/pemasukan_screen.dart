import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../theme/app_colors.dart';
import '../database/database_helper.dart';
import '../models/transaction_model.dart';
import 'package:pattern_formatter/pattern_formatter.dart';

class PemasukanScreen extends StatefulWidget {
  const PemasukanScreen({super.key});

  @override
  State<PemasukanScreen> createState() => PemasukanScreenState();
}

class PemasukanScreenState extends State<PemasukanScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _currencyFormat = NumberFormat('#,##0', 'id_ID');

  double _totalIncome = 0;
  List<TransactionModel> _incomes = [];
  bool _isLoading = true;
  String _selectedFilter = 'Semua';

  final List<String> _filters = [
    'Semua',
    'Dana BOS',
    'Pinjaman',
    'Sumbangan',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void reload() => _loadData();

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _totalIncome = await _dbHelper.getTotalIncome();
    final allTx = await _dbHelper.getAllTransactions();
    _incomes = allTx.where((t) => t.type == 'income').toList();
    setState(() => _isLoading = false);
  }

  List<TransactionModel> get _filteredIncomes {
    if (_selectedFilter == 'Semua') return _incomes;
    if (_selectedFilter == 'Dana BOS') {
      return _incomes.where((t) => t.category == 'BOS Fund').toList();
    }
    if (_selectedFilter == 'Pinjaman') {
      return _incomes.where((t) => t.category == 'Pinjaman').toList();
    }
    if (_selectedFilter == 'Sumbangan') {
      return _incomes.where((t) => t.category == 'Sumbangan').toList();
    }
    return _incomes
        .where(
          (t) =>
              t.category != 'BOS Fund' &&
              t.category != 'Pinjaman' &&
              t.category != 'Sumbangan',
        )
        .toList();
  }

  String _formatCurrency(double amount) {
    return 'Rp ${_currencyFormat.format(amount.toInt())}';
  }

  IconData _getIcon(String category) {
    switch (category) {
      case 'BOS Fund':
        return Icons.account_balance;
      case 'Pinjaman':
        return Icons.description;
      case 'Sumbangan':
        return Icons.favorite;
      default:
        return Icons.savings;
    }
  }

  Color _getIconColor(String category) {
    switch (category) {
      case 'BOS Fund':
        return AppColors.primary;
      case 'Pinjaman':
        return Colors.amber.shade600;
      case 'Sumbangan':
        return Colors.pink.shade500;
      default:
        return AppColors.emerald600;
    }
  }

  Color _getIconBg(String category) {
    switch (category) {
      case 'BOS Fund':
        return AppColors.primary.withValues(alpha: 0.15);
      case 'Pinjaman':
        return Colors.amber.shade50;
      case 'Sumbangan':
        return Colors.pink.shade50;
      default:
        return AppColors.mint;
    }
  }

  String _getIconName(String category) {
    switch (category) {
      case 'Pinjaman':
        return 'description';
      case 'Sumbangan':
        return 'favorite';
      default:
        return 'savings';
    }
  }

  // ==================== ADD / EDIT INCOME ====================

  Future<void> _showAddIncomeDialog() async {
    final selectedCategory = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Pilih Kategori Pemasukan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dana BOS otomatis masuk dari halaman BOS.\nPilih kategori lain untuk input manual.',
                style: TextStyle(fontSize: 13, color: Colors.black45),
              ),
              const SizedBox(height: 20),
              _buildCatOption(
                ctx,
                'Dana BOS',
                'Otomatis dari pencairan BOS',
                Icons.account_balance,
                AppColors.primary,
                isDisabled: true,
              ),
              const SizedBox(height: 10),
              _buildCatOption(
                ctx,
                'Pinjaman',
                'Pinjaman modal kerja, dll',
                Icons.description,
                Colors.amber.shade600,
              ),
              const SizedBox(height: 10),
              _buildCatOption(
                ctx,
                'Sumbangan',
                'Donasi alumni, wali murid, dll',
                Icons.favorite,
                Colors.pink.shade500,
              ),
              const SizedBox(height: 10),
              _buildCatOption(
                ctx,
                'Lainnya',
                'Pemasukan dari sumber lain',
                Icons.more_horiz,
                AppColors.emerald600,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (selectedCategory != null && mounted) {
      _showInputForm(selectedCategory, null);
    }
  }

  Widget _buildCatOption(
    BuildContext ctx,
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : () => Navigator.pop(ctx, title),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.shade200
                : color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDisabled
                    ? Colors.grey.shade200
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDisabled ? Colors.grey.shade400 : color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDisabled
                          ? Colors.grey.shade400
                          : AppColors.textDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDisabled ? Colors.grey.shade400 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            if (isDisabled)
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

  Future<void> _showInputForm(
    String category,
    TransactionModel? existing,
  ) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final amountController = TextEditingController(
      text: existing != null ? existing.amount.toInt().toString() : '',
    );
    final descController = TextEditingController(
      text: existing?.description ?? '',
    );
    DateTime selectedDate = existing?.date ?? DateTime.now();
    final isEdit = existing != null;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
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
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getIconBg(category),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getIcon(category),
                            color: _getIconColor(category),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isEdit ? 'Edit $category' : 'Tambah $category',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'Judul',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Sumbangan Alumni',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Amount Input
                    const Text(
                      'Jumlah',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: false,
                        signed: false,
                      ),
                      inputFormatters: [ThousandsFormatter()],
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        hintText: '0',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        suffixIcon: InkWell(
                          onTap: () {
                            final text = amountController.text.replaceAll(
                              '.',
                              '',
                            );
                            if (text.isNotEmpty) {
                              amountController.text = text + '000';
                            } else {
                              amountController.text = '000';
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Text(
                                '000',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date
                    const Text(
                      'Tanggal',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: AppColors.primary,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd MMMM yyyy').format(selectedDate),
                            ),
                            const Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    const Text(
                      'Keterangan (Opsional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Catatan...',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final amountText = amountController.text.replaceAll(
                            '.',
                            '',
                          );
                          final amount = double.tryParse(amountText) ?? 0;
                          if (amount <= 0 ||
                              titleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Lengkapi judul dan jumlah'),
                              ),
                            );
                            return;
                          }

                          if (isEdit) {
                            final updated = existing.copyWith(
                              title: titleController.text.trim(),
                              category: category,
                              amount: amount,
                              date: selectedDate,
                              description: descController.text.trim().isEmpty
                                  ? null
                                  : descController.text.trim(),
                              icon: _getIconName(category),
                            );
                            await _dbHelper.updateTransaction(updated);
                          } else {
                            final transaction = TransactionModel(
                              title: titleController.text.trim(),
                              category: category,
                              amount: amount,
                              type: 'income',
                              date: selectedDate,
                              description: descController.text.trim().isEmpty
                                  ? null
                                  : descController.text.trim(),
                              icon: _getIconName(category),
                            );
                            await _dbHelper.insertTransaction(transaction);
                          }
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        },
                        icon: const Icon(Icons.check),
                        label: Text(
                          isEdit ? 'Simpan Perubahan' : 'Simpan Pemasukan',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) _loadData();
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final items = _filteredIncomes;

    return Scaffold(
      backgroundColor: Colors.white,
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
                    backgroundColor: Colors.white,
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    centerTitle: true,
                    title: const Text(
                      'Pemasukan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildSummaryCard(),
                        _buildFilterChips(),
                        _buildTransactionList(items),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_pemasukan',
        onPressed: _showAddIncomeDialog,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 6,
        child: const Icon(Icons.add, size: 30, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Pemasukan Bulan Ini',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatCurrency(_totalIncome),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 14,
                    color: AppColors.emerald600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_incomes.length} transaksi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.emerald600,
                    ),
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
    return SizedBox(
      height: 50,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 6,
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transaksi Terbaru',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.south_west,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada pemasukan',
                      style: TextStyle(color: Colors.black45, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            ...items.map((tx) {
              final dateFormat = DateFormat('dd MMM yyyy');
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Slidable(
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.5,
                    children: [
                      SlidableAction(
                        onPressed: (_) => _showInputForm(tx.category, tx),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        icon: Icons.edit,
                        label: 'Edit',
                        borderRadius: BorderRadius.circular(14),
                      ),
                      SlidableAction(
                        onPressed: (_) async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hapus Pemasukan'),
                              content: const Text(
                                'Yakin ingin menghapus pemasukan ini? Saldo akan dikurangi.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Batal'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Hapus',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && tx.id != null) {
                            // Recover balance when deleting income
                            final amount = tx.amount;
                            final isBos = tx.category == 'BOS Fund';
                            final fundName = isBos ? 'BOS Fund' : 'Other Fund';
                            final funds = await _dbHelper.getAllFunds();
                            for (final fund in funds) {
                              if (fund.name == fundName) {
                                await _dbHelper.updateFundBalance(
                                  fund.name,
                                  fund.balance - amount,
                                );
                                break;
                              }
                            }
                            await _dbHelper.deleteTransaction(tx.id!);
                            _loadData();
                          }
                        },
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
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
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
                            color: _getIconBg(tx.category),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getIcon(tx.category),
                            color: _getIconColor(tx.category),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${dateFormat.format(tx.date)} • ${tx.category == "BOS Fund" ? "Dana BOS" : tx.category}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+ ${_formatCurrency(tx.amount)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
