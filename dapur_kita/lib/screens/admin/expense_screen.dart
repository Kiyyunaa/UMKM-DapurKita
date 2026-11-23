import 'package:flutter/material.dart';
import '../../models/expense_model.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/custom_text_field.dart';

/// Halaman Kelola Biaya Operasional & Pengeluaran (Admin)
class AdminExpenseScreen extends StatefulWidget {
  const AdminExpenseScreen({super.key});

  @override
  State<AdminExpenseScreen> createState() => _AdminExpenseScreenState();
}

class _AdminExpenseScreenState extends State<AdminExpenseScreen> {
  List<ExpenseModel> _expenses = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await ApiService.get('/api/expenses');
      final list = (res['data'] as List? ?? [])
          .map((e) => ExpenseModel.fromJson(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _expenses = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showExpenseDialog({ExpenseModel? expense}) {
    final titleController = TextEditingController(text: expense?.title ?? '');
    final amountController = TextEditingController(text: expense != null ? expense.amount.toInt().toString() : '');
    final descController = TextEditingController(text: expense?.description ?? '');
    String selectedCategory = expense?.category ?? 'raw_material';
    String expenseDate = expense?.expenseDate ?? DateTime.now().toIso8601String().split('T').first;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            expense == null ? 'Catat Pengeluaran Baru' : 'Ubah Pengeluaran',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomTextField(
                  controller: titleController,
                  label: 'Judul Pengeluaran',
                  hint: 'Contoh: Beli bensin kurir, Kantong kresek',
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: amountController,
                  label: 'Nominal Biaya (Rp)',
                  hint: 'Contoh: 50000',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                const Text('Kategori Pengeluaran', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'raw_material', child: Text('Peralatan / Bahan')),
                    DropdownMenuItem(value: 'packaging', child: Text('Kemasan / Plastik')),
                    DropdownMenuItem(value: 'fuel', child: Text('Bensin / BBM')),
                    DropdownMenuItem(value: 'utility', child: Text('Utilitas (Listrik/Air)')),
                    DropdownMenuItem(value: 'other', child: Text('Lainnya')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: descController,
                  label: 'Keterangan Tambahan',
                  hint: 'Opsional...',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal Pengeluaran', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(expenseDate.split('T').first),
                  trailing: const Icon(Icons.calendar_today_outlined, color: AppColors.forestGreen),
                  onTap: () async {
                    final sekarang = DateTime.now();
                    final pilihan = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(expenseDate) ?? sekarang,
                      firstDate: DateTime(sekarang.year - 2),
                      lastDate: DateTime(sekarang.year + 1),
                    );
                    if (pilihan != null) {
                      setDialogState(() {
                        expenseDate = pilihan.toIso8601String().split('T').first;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: AppColors.white,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final judul = titleController.text.trim();
                      final nominal = double.tryParse(amountController.text.trim());
                      if (judul.length < 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Judul pengeluaran minimal 2 karakter.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      if (nominal == null || nominal <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nominal harus berupa angka lebih dari 0.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        final payload = {
                          'title': judul,
                          'category': selectedCategory,
                          'amount': nominal,
                          'expense_date': expenseDate,
                          'description': descController.text.trim(),
                        };

                        if (expense == null) {
                          await ApiService.post('/api/expenses', payload);
                        } else {
                          await ApiService.put('/api/expenses/${expense.id}', payload);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _fetchExpenses();
                      } catch (e) {
                        if (!ctx.mounted) return;
                        setDialogState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExpense(ExpenseModel expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengeluaran?'),
        content: Text('Hapus pengeluaran "${expense.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.delete('/api/expenses/${expense.id}');
        _fetchExpenses();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus pengeluaran: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: const Text(
          'Biaya Operasional',
          style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.forestGreen))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.forestGreen),
                          onPressed: _fetchExpenses,
                          child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
              onRefresh: _fetchExpenses,
              color: AppColors.forestGreen,
              child: _expenses.isEmpty
                  ? const Center(child: Text('Belum ada catatan pengeluaran.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _expenses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final exp = _expenses[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.mutedOrange.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.money_off, color: AppColors.mutedOrange, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exp.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${exp.categoryDisplay} • ${Formatters.formatDate(exp.expenseDate)}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      Formatters.formatRupiah(exp.amount),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppColors.forestGreen, size: 20),
                                onPressed: () => _showExpenseDialog(expense: exp),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                onPressed: () => _deleteExpense(exp),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.forestGreen,
        icon: const Icon(Icons.add, color: AppColors.white),
        label: const Text('Catat Biaya', style: TextStyle(color: AppColors.white)),
        onPressed: () => _showExpenseDialog(),
      ),
    );
  }
}
