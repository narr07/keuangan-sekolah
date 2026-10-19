import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../theme/app_colors.dart';
import '../database/database_helper.dart';
import '../models/bos_disbursement_model.dart';
import '../models/bos_pagu_model.dart';
import '../widgets/form_widgets.dart';
import '../widgets/indonesian_currency_formatter.dart';

class BosScreen extends StatefulWidget {
  const BosScreen({super.key});

  @override
  State<BosScreen> createState() => BosScreenState();
}

class BosScreenState extends State<BosScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _currencyFormat = NumberFormat('#,##0', 'id_ID');

  int _year = DateTime.now().year;
  BosPaguModel _pagu = BosPaguModel(year: DateTime.now().year);
  List<BosDisbursementModel> _disbursements = [];
  double _totalCairSemester1 = 0;
  double _totalCairSemester2 = 0;
  double _totalCairAll = 0;
  bool _isLoading = true;
  int _selectedSemester = 0; // 0 = all, 1 = semester 1, 2 = semester 2

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void reload() => _loadData();

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final year = (await _dbHelper.getSettings()).activeYear;
    final pagu = await _dbHelper.getPagu(year);
    final disbursements = await _dbHelper.getBosDisbursementsByYear(year);
    final cairS1 = await _dbHelper.getTotalBosCair(year, semester: 1);
    final cairS2 = await _dbHelper.getTotalBosCair(year, semester: 2);
    final cairAll = await _dbHelper.getTotalBosCair(year);
    if (!mounted) return;

    setState(() {
      _year = year;
      _pagu = pagu;
      _disbursements = disbursements;
      _totalCairSemester1 = cairS1;
      _totalCairSemester2 = cairS2;
      _totalCairAll = cairAll;
      _isLoading = false;
    });
  }

  String _formatCurrency(double amount) {
    return 'Rp ${_currencyFormat.format(amount.toInt())}';
  }

  String _formatShort(double amount) {
    if (amount >= 1000000000) {
      return 'Rp ${(amount / 1000000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(1)}jt';
    }
    return _formatCurrency(amount);
  }

  List<BosDisbursementModel> get _filteredDisbursements {
    if (_selectedSemester == 0) return _disbursements;
    return _disbursements
        .where((d) => d.semester == _selectedSemester)
        .toList();
  }

  Future<void> _showDisbursementForm(BosDisbursementModel? existing) async {
    final isEdit = existing != null;
    var amountText = isEdit
        ? _currencyFormat.format(existing.amount.toInt())
        : '';
    final phaseController = TextEditingController(text: existing?.phase ?? '');
    final descController = TextEditingController(
      text: existing?.description ?? '',
    );
    final now = DateTime.now();
    DateTime selectedDate =
        existing?.date ?? (_year >= now.year ? now : DateTime(_year, 12, 31));
    String selectedStatus = existing?.status ?? 'Cair';
    int selectedSemester =
        existing?.semester ?? (selectedDate.month <= 6 ? 1 : 2);

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
                    const SheetHandle(),
                    const SizedBox(height: 20),
                    Text(
                      isEdit ? 'Edit Pencairan BOS' : 'Tambah Pencairan BOS',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const FormLabel('Jumlah Dana'),
                    AmountPickerField(
                      value: amountText,
                      title: 'Jumlah Dana BOS',
                      onChanged: (v) => setModalState(() => amountText = v),
                    ),
                    const SizedBox(height: 16),

                    const FormLabel('Tahap Pencairan'),
                    TextFormField(
                      controller: phaseController,
                      decoration: formInputDecoration('Contoh: Tahap 1'),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown<int>(
                            label: 'Semester',
                            value: selectedSemester,
                            items: const {1: 'Semester 1', 2: 'Semester 2'},
                            onChanged: (v) =>
                                setModalState(() => selectedSemester = v),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdown<String>(
                            label: 'Status',
                            value: selectedStatus,
                            items: const {'Cair': 'Cair', 'Proses': 'Proses'},
                            onChanged: (v) =>
                                setModalState(() => selectedStatus = v),
                          ),
                        ),
                      ],
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
                      decoration: formInputDecoration('Catatan tambahan...'),
                    ),
                    const SizedBox(height: 24),

                    SaveButton(
                      label: isEdit ? 'Simpan Perubahan' : 'Simpan Pencairan',
                      onPressed: () async {
                        final amount = IndonesianCurrencyFormatter.parse(
                          amountText,
                        );
                        if (amount <= 0 ||
                            phaseController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Lengkapi jumlah dan tahap'),
                            ),
                          );
                          return;
                        }

                        final description = descController.text.trim();
                        final disbursement = BosDisbursementModel(
                          id: existing?.id,
                          amount: amount,
                          date: selectedDate,
                          phase: phaseController.text.trim(),
                          status: selectedStatus,
                          description: description.isEmpty ? null : description,
                          semester: selectedSemester,
                        );

                        if (isEdit) {
                          await _dbHelper.updateBosDisbursement(disbursement);
                        } else {
                          await _dbHelper.insertBosDisbursement(disbursement);
                        }
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      },
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

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormLabel(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: [
                for (final e in items.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Form isian pagu BOS untuk tahun anggaran yang sedang dibuka.
  Future<void> _showPaguForm() async {
    var s1 = _currencyFormat.format(_pagu.semester1.toInt());
    var s2 = _currencyFormat.format(_pagu.semester2.toInt());

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 20),
              Text(
                'Pagu BOS Tahun $_year',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Batas dana BOS yang dialokasikan per semester. Setiap tahun '
                'anggaran punya pagu sendiri.',
                style: TextStyle(fontSize: 13, color: Colors.black45),
              ),
              const SizedBox(height: 20),
              const FormLabel('Pagu Semester 1 (Jan - Jun)'),
              AmountPickerField(
                value: s1,
                title: 'Pagu Semester 1',
                onChanged: (v) => setModalState(() => s1 = v),
              ),
              const SizedBox(height: 16),
              const FormLabel('Pagu Semester 2 (Jul - Des)'),
              AmountPickerField(
                value: s2,
                title: 'Pagu Semester 2',
                onChanged: (v) => setModalState(() => s2 = v),
              ),
              const SizedBox(height: 24),
              SaveButton(
                label: 'Simpan Pagu',
                onPressed: () async {
                  await _dbHelper.setPagu(
                    BosPaguModel(
                      year: _year,
                      semester1: IndonesianCurrencyFormatter.parse(s1),
                      semester2: IndonesianCurrencyFormatter.parse(s2),
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) _loadData();
  }

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
                    backgroundColor: AppColors.backgroundLight.withValues(
                      alpha: 0.9,
                    ),
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    title: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dana BOS',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              'Tahun Anggaran $_year',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.only(right: 16),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // Pagu Progress
                        _buildPaguProgress(),
                        // Summary Cards
                        _buildSummaryCards(),
                        // Semester Filter
                        _buildSemesterFilter(),
                        // Disbursement List
                        _buildDisbursementList(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_bos',
        onPressed: () => _showDisbursementForm(null),
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 6,
        child: const Icon(Icons.add, size: 30, color: Colors.white),
      ),
    );
  }

  Widget _buildPaguProgress() {
    final totalPagu = _pagu.total;
    final progress = totalPagu > 0
        ? (_totalCairAll / totalPagu).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: _showPaguForm,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Realisasi Pagu BOS',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      totalPagu > 0
                          ? '${(progress * 100).toStringAsFixed(1)}%'
                          : 'Pagu belum diisi',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _formatCurrency(_totalCairAll),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      totalPagu > 0
                          ? 'dari pagu ${_formatCurrency(totalPagu)}'
                          : 'Ketuk untuk mengisi pagu tahun $_year',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final paguS1 = _pagu.semester1;
    final paguS2 = _pagu.semester2;
    final progressS1 = paguS1 > 0
        ? (_totalCairSemester1 / paguS1).clamp(0.0, 1.0)
        : 0.0;
    final progressS2 = paguS2 > 0
        ? (_totalCairSemester2 / paguS2).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildSemesterCard(
              'Semester 1',
              'Jan - Jun',
              _totalCairSemester1,
              paguS1,
              progressS1,
              AppColors.emerald600,
              Colors.green.shade50,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSemesterCard(
              'Semester 2',
              'Jul - Des',
              _totalCairSemester2,
              paguS2,
              progressS2,
              AppColors.purple600,
              AppColors.pastelPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterCard(
    String title,
    String period,
    double cair,
    double pagu,
    double progress,
    Color accentColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          Text(
            period,
            style: const TextStyle(fontSize: 10, color: Colors.black45),
          ),
          const SizedBox(height: 10),
          Text(
            _formatShort(cair),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Text(
            '/ ${_formatShort(pagu)}',
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: accentColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterFilter() {
    final filters = ['Semua', 'Semester 1', 'Semester 2'];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(filters.length, (i) {
          final isSelected = _selectedSemester == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedSemester = i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  filters[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDisbursementList() {
    final items = _filteredDisbursements;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Riwayat Pencairan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                '${items.length} Pencairan',
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
                      Icons.account_balance_wallet_outlined,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada pencairan',
                      style: TextStyle(color: Colors.black45),
                    ),
                  ],
                ),
              ),
            )
          else
            ...items.map((d) {
              final dateFormat = DateFormat('dd MMM yyyy');
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Slidable(
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.5,
                    children: [
                      SlidableAction(
                        onPressed: (_) => _showDisbursementForm(d),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        icon: Icons.edit,
                        label: 'Edit',
                        borderRadius: BorderRadius.circular(14),
                      ),
                      SlidableAction(
                        onPressed: (_) async {
                          final confirm = await confirmDelete(
                            context,
                            title: 'Hapus Pencairan',
                            message:
                                'Yakin ingin menghapus pencairan ini? Pemasukan '
                                'Dana BOS yang tertaut juga ikut terhapus.',
                          );
                          if (confirm && d.id != null) {
                            await _dbHelper.deleteBosDisbursement(d.id!);
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
                      borderRadius: BorderRadius.circular(14),
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
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.phase,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${dateFormat.format(d.date)} • Semester ${d.semester}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatShort(d.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: d.status == 'Cair'
                                    ? Colors.green.shade50
                                    : Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                d.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: d.status == 'Cair'
                                      ? AppColors.emerald600
                                      : Colors.amber.shade700,
                                ),
                              ),
                            ),
                          ],
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
