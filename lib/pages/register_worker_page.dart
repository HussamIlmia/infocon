import 'dart:async';
import 'package:flutter/material.dart';
import 'package:info_console_app/all_models.dart';
import 'package:info_console_app/api_service.dart';
import '../layouts/dashboard_layout.dart';

class RegisterWorkerPage extends StatefulWidget {
  final String companyId;
  const RegisterWorkerPage({super.key, required this.companyId});

  @override
  State<RegisterWorkerPage> createState() => _RegisterWorkerPageState();
}

class _RegisterWorkerPageState extends State<RegisterWorkerPage> {
  final TextEditingController _workerNameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  final RegExp _passwordRegExp = RegExp(
    "^[a-zA-Z0-9!@#\$%^&*()_+\\-=\\[\\]{}\\\\|;:'\",.<>\\/?~]+\$"
  );

  List<RegisteredWorker> _registeredWorkers = [];
  List<RegisteredWorker> _filteredWorkers = [];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchWorkers();
  }

  Future<void> _fetchWorkers() async {
    setState(() => _isLoading = true);
    try {
      final loadedWorkers = await ApiService.fetchWorkers();
      _registeredWorkers = loadedWorkers;
      _filteredWorkers = List.from(loadedWorkers);
    } catch (e) {
      debugPrint("Exception while fetching workers: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ユーザー一覧の取得に失敗しました: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterWorkerList(String query) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) {
      _filteredWorkers = List.from(_registeredWorkers);
    } else {
      _filteredWorkers = _registeredWorkers
          .where((w) => w.workerName.toLowerCase().contains(text))
          .toList();
    }
    setState(() {});
  }

  Future<void> _registerWorker() async {
    final workerName = _workerNameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (workerName.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ユーザー名とパスワードを入力してください。")),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("パスワードは6文字以上にしてください。")),
      );
      return;
    }

    // Validate password characters
    if (!_passwordRegExp.hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "パスワードに使用できない文字が含まれています。\n"
            "英数字と以下の記号のみ使用できます：\n !@#\$%^&*()_+…など"
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await ApiService.registerWorker(
        workerName: workerName,
        password: password,
        parentCompanyId: widget.companyId,
      );
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ユーザーが登録されました。")),
        );
        _workerNameCtrl.clear();
        _passwordCtrl.clear();
        await _fetchWorkers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("登録に失敗しました。")),
        );
      }
    } catch (e) {
      debugPrint("Exception during registration: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("エラー: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showConfirmDeleteDialog(RegisteredWorker worker) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("ユーザー削除の確認"),
          content: Text(
            "ユーザー「${worker.workerName}」を削除しますか？\nこの操作は取り消せません。",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("キャンセル"),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                _deleteWorker(worker.workerId, worker.workerName);
              },
              child: const Text("削除"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteWorker(String workerId, String workerName) async {
    setState(() => _isLoading = true);
    try {
      final success = await ApiService.deleteWorker(workerId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ユーザー「$workerName」が削除されました。")),
        );
        await _fetchWorkers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("ユーザーの削除に失敗しました。"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("Exception while deleting worker: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("エラーが発生しました: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _filterWorkerList(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          ignoring: _isLoading,
          child: DashboardLayout(
            selectedNavIndex: 1,
            companyId: widget.companyId,
            content: _buildMainContent(),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildMainContent() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.2),
            colorScheme.primaryContainer.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                _buildActionsRow(),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRegistrationForm(colorScheme),
                        const SizedBox(height: 24),
                        _buildSearchBar(colorScheme),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            "現在のユーザー数: ${_filteredWorkers.length}",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildWorkerTable(colorScheme),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "再読み込み",
            onPressed: _fetchWorkers,
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm(ColorScheme colorScheme) {
    return Card(
      elevation: 4,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "新しいユーザーを登録",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _workerNameCtrl,
              decoration: InputDecoration(
                labelText: "ユーザー名",
                prefixIcon: const Icon(Icons.person),
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: "パスワード",
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _registerWorker,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 24),
                label: const Text(
                  "登録する",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Card(
      elevation: 4,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          labelText: "ユーザー検索",
          hintText: "ユーザー名で検索",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    _filterWorkerList("");
                  },
                )
              : null,
          filled: true,
          fillColor: colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildWorkerTable(ColorScheme colorScheme) {
    if (_filteredWorkers.isEmpty) {
      bool isEmptyBaseList = _registeredWorkers.isEmpty;
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            isEmptyBaseList
                ? "登録されたユーザーはいません。"
                : "検索結果がありません。",
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    List<DataRow> dataRows = [];
    for (int i = 0; i < _filteredWorkers.length; i++) {
      final worker = _filteredWorkers[i];
      final rowColor =
          (i % 2 == 0) ? colorScheme.primaryContainer.withValues(alpha: 0.1) : null;

      dataRows.add(
        DataRow(
          color: WidgetStateProperty.resolveWith<Color?>(
            (states) {
              if (states.contains(WidgetState.hovered)) {
                return colorScheme.primaryContainer.withValues(alpha: 0.2);
              }
              return rowColor;
            },
          ),
          cells: [
            DataCell(Text(worker.workerId)),
            DataCell(Text(worker.workerName)),
            DataCell(
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: "削除",
                onPressed: () => _showConfirmDeleteDialog(worker),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 4,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  headingTextStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  columns: const [
                    DataColumn(label: Text("ユーザーID")),
                    DataColumn(label: Text("ユーザー名")),
                    DataColumn(label: Text("操作")),
                  ],
                  rows: dataRows,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
