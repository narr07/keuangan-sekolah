import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../database/database_helper.dart';
import '../models/settings_model.dart';
import '../services/export_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper.instance;
  final _schoolNameController = TextEditingController();
  final _paguSemester1Controller = TextEditingController();
  final _paguSemester2Controller = TextEditingController();
  final _tahunAnggaranController = TextEditingController();
  final _currencyFormat = NumberFormat('#,##0', 'id_ID');

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _paguSemester1Controller.dispose();
    _paguSemester2Controller.dispose();
    _tahunAnggaranController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final settings = await _dbHelper.getSettings();
    _schoolNameController.text = settings.schoolName;
    _paguSemester1Controller.text = _currencyFormat.format(
      settings.paguSemester1.toInt(),
    );
    _paguSemester2Controller.text = _currencyFormat.format(
      settings.paguSemester2.toInt(),
    );
    _tahunAnggaranController.text = settings.tahunAnggaran;
    setState(() => _isLoading = false);
  }

  double _parseAmount(String text) {
    // Handle Indonesian format: dots as thousands, comma as decimal
    // Remove dots (thousands separator), replace comma with dot for parsing
    String cleaned = text.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final settings = SettingsModel(
      schoolName: _schoolNameController.text.trim(),
      paguSemester1: _parseAmount(_paguSemester1Controller.text),
      paguSemester2: _parseAmount(_paguSemester2Controller.text),
      tahunAnggaran: _tahunAnggaranController.text.trim(),
    );

    await _dbHelper.updateSettings(settings);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pengaturan berhasil disimpan!'),
          backgroundColor: AppColors.emerald600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pengaturan',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // About App Section
                    _buildSectionHeader('Tentang Aplikasi', Icons.info_outline),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
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
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.developer_mode,
                              color: AppColors.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'BudgetKu Edu',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Aplikasi Manajemen Keuangan\nVersi 1.0.0',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                    height: 1.4,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Dikembangkan oleh:\nDinar Permadi - permadi.dev',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // School Info Section
                    _buildSectionHeader('Informasi Sekolah', Icons.school),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'Nama Sekolah',
                      controller: _schoolNameController,
                      hint: 'Masukkan nama sekolah',
                      icon: Icons.business,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nama sekolah wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'Tahun Anggaran',
                      controller: _tahunAnggaranController,
                      hint: 'Contoh: 2024',
                      icon: Icons.calendar_today,
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Tahun anggaran wajib diisi'
                          : null,
                    ),

                    const SizedBox(height: 32),

                    // Pagu Anggaran Section
                    _buildSectionHeader(
                      'Pagu Anggaran BOS',
                      Icons.account_balance_wallet,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Pagu anggaran adalah batas maksimal dana BOS yang dialokasikan per semester.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'Pagu Semester 1 (Jan - Jun)',
                      controller: _paguSemester1Controller,
                      hint: 'Contoh: 225.000.000',
                      icon: Icons.looks_one,
                      prefix: 'Rp ',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Pagu semester 1 wajib diisi';
                        }
                        if (_parseAmount(v) <= 0) return 'Jumlah tidak valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'Pagu Semester 2 (Jul - Des)',
                      controller: _paguSemester2Controller,
                      hint: 'Contoh: 225.000.000',
                      icon: Icons.looks_two,
                      prefix: 'Rp ',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Pagu semester 2 wajib diisi';
                        }
                        if (_parseAmount(v) <= 0) return 'Jumlah tidak valid';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Total pagu preview
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Pagu Setahun',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Rp ${_currencyFormat.format((_parseAmount(_paguSemester1Controller.text) + _parseAmount(_paguSemester2Controller.text)).toInt())}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveSettings,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _isSaving ? 'Menyimpan...' : 'Simpan Pengaturan',
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
                    const SizedBox(height: 32),

                    // Export Section
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildSectionHeader(
                      'Ekspor Laporan',
                      Icons.download_rounded,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unduh seluruh laporan keuangan dalam bentuk PDF atau Excel.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _handleExport('pdf'),
                            icon: const Icon(
                              Icons.picture_as_pdf,
                              color: Colors.red,
                            ),
                            label: const Text('Ekspor PDF'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Colors.red),
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _handleExport('excel'),
                            icon: const Icon(
                              Icons.table_view,
                              color: Colors.green,
                            ),
                            label: const Text('Ekspor Excel'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Colors.green),
                              foregroundColor: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _handleExport(String type) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final transactions = await _dbHelper.getAllTransactions();
      final settings = await _dbHelper.getSettings();

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (type == 'pdf') {
        await ExportService.exportToPdf(transactions, settings.schoolName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Berhasil diekspor ke PDF!')),
          );
        }
      } else {
        await ExportService.exportToExcel(transactions, settings.schoolName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Berhasil diekspor ke Excel!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Force close dialog if error occurred
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? prefix,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: Colors.white,
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
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
