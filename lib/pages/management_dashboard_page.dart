import 'dart:async';
import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart' as dt;
import 'package:info_console_app/all_models.dart';  // Contains Inquiry model
import '../api_service.dart';
import '../components/chat_link_dialog.dart';
import '../layouts/dashboard_layout.dart';

class InquiryDataTableSource extends DataTableSource {
  final List<Inquiry> inquiries;
  final void Function(Inquiry) onInquiryTap;

  InquiryDataTableSource({
    required this.inquiries,
    required this.onInquiryTap,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= inquiries.length) return null;
    final inq = inquiries[index];
    final rowColor = inq.isRead ? Colors.white : const Color(0xFFEEF1FA);

    Color statusTextColor = Colors.black87;
    if (inq.status == "完了") statusTextColor = Colors.green.shade800;
    else if (inq.status == "進行中") statusTextColor = Colors.orange.shade800;
    else if (inq.status == "未着手") statusTextColor = Colors.red.shade800;

    return DataRow(
      color: WidgetStateProperty.resolveWith((_) => rowColor),
      onSelectChanged: (selected) {
        if (selected ?? false) {
          onInquiryTap(inq);
        }
      },
      cells: [
        DataCell(Text(
          inq.inquiryId,
          style: TextStyle(
            fontWeight: inq.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        )),
        DataCell(Text(
          inq.buildingName,
          style: TextStyle(
            fontWeight: inq.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        )),
        DataCell(Text(inq.inquiryType)),
        DataCell(Text(inq.status, style: TextStyle(color: statusTextColor))),
        DataCell(Text(inq.assignedTo.isEmpty ? '担当者なし' : inq.assignedTo)),
        DataCell(Text(inq.createdAt)),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => inquiries.length;
  @override
  int get selectedRowCount => 0;

  void sort(int columnIndex, bool ascending) {
    inquiries.sort((a, b) {
      int compare = 0;
      switch (columnIndex) {
        case 0:
          compare = a.inquiryId.compareTo(b.inquiryId);
          break;
        case 1:
          compare = a.buildingName.compareTo(b.buildingName);
          break;
        case 2:
          compare = a.inquiryType.compareTo(b.inquiryType);
          break;
        case 3:
          compare = a.status.compareTo(b.status);
          break;
        case 4:
          compare = a.assignedTo.compareTo(b.assignedTo);
          break;
        case 5:
          compare = a.createdAt.compareTo(b.createdAt);
          break;
      }
      return ascending ? compare : -compare;
    });
    notifyListeners();
  }
}

class ManagementDashboard extends StatefulWidget {
  final String companyId;
  const ManagementDashboard({super.key, required this.companyId});

  @override
  State<ManagementDashboard> createState() => _ManagementDashboardState();
}

class _ManagementDashboardState extends State<ManagementDashboard> {
  final TextEditingController _filterController = TextEditingController();
  final GlobalKey<DashboardLayoutState> _dashKey = GlobalKey<DashboardLayoutState>();

  List<Inquiry> _allInquiries = [];
  List<Inquiry> _filteredInquiries = [];
  late InquiryDataTableSource _dataSource;

  bool _isLoading = false;
  bool _showOnlyUnread = false;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  int _rowsPerPage = 10;

  Timer? _debounce;
  Key _tableKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      final inquiries = await ApiService.fetchInquiries(widget.companyId);
      // Sort descending by createdAtISO
      inquiries.sort((a, b) => b.createdAtISO.compareTo(a.createdAtISO));
      _allInquiries = inquiries;
      _filteredInquiries = List.from(_allInquiries);
      _applyFilters();
      _refreshDataSource();
    } catch (e) {
      debugPrint("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("データの読み込みに失敗しました: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _refreshDataSource() {
    _dataSource = InquiryDataTableSource(
      inquiries: _filteredInquiries,
      onInquiryTap: _openInquiryDetail,
    );
    if (_sortColumnIndex != null) {
      _dataSource.sort(_sortColumnIndex!, _sortAscending);
    }
    _tableKey = UniqueKey();
  }

  void _openInquiryDetail(Inquiry inq) {
    setState(() {
      inq.isRead = true;
    });
    // CHANGED HERE: pass assignedToId as well
    ApiService.updateInquiry(
      companyId: widget.companyId,
      inquiry: inq,
      newStatus: inq.status,
      newWorkerName: inq.assignedTo,   // worker name
      newWorkerId: inq.assignedToId,   // worker ID
      isRead: true,
    ).then((success) {
      if (!success) {
        debugPrint("ステータス更新失敗: ${inq.inquiryId}");
      }
    });

    // Immediately update the unread count in the sidebar via GlobalKey
    _dashKey.currentState?.refreshUnreadCount();

    Navigator.pushNamed(
    context,
    '/inquiryDetail',
    arguments: {
      'companyId': widget.companyId,
      'inquiryId': inq.inquiryId,
    },
  ).then((_) {
    // This callback fires when InquiryDetailPage is popped.
    // So now we can refresh the data to ensure it's up to date:
    _onRefresh(); 
    // or: _fetchAllData();
  });
  }

  void _onFilterChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _applyFilter(text);
    });
  }

  void _applyFilter(String value) {
    final text = value.trim().toLowerCase();
    if (text.isEmpty) {
      _filteredInquiries = List.from(_allInquiries);
    } else {
      _filteredInquiries = _allInquiries.where((inq) {
        return inq.inquiryId.toLowerCase().contains(text) ||
            inq.status.toLowerCase().contains(text) ||
            inq.assignedTo.toLowerCase().contains(text) ||
            inq.inquiryType.toLowerCase().contains(text) ||
            inq.buildingName.toLowerCase().contains(text);
      }).toList();
    }
    _applyUnreadFilter();
    _refreshDataSource();
  }

  void _applyUnreadFilter() {
    if (_showOnlyUnread) {
      _filteredInquiries = _filteredInquiries.where((inq) => !inq.isRead).toList();
    }
  }

  void _applyFilters() {
    _applyFilter(_filterController.text);
  }

  Future<void> _onRefresh() async {
    await _fetchAllData();
    // Also refresh sidebar unread
    _dashKey.currentState?.refreshUnreadCount();
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _dataSource.sort(columnIndex, ascending);
      _tableKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          ignoring: _isLoading,
          child: DashboardLayout(
            key: _dashKey, 
            selectedNavIndex: 0,
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
            colorScheme.primaryContainer.withOpacity(0.2),
            colorScheme.primaryContainer.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildActionsRow(),
            const SizedBox(height: 12),
            _buildStatsRow(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(12),
                child: TextField(
                  controller: _filterController,
                  onChanged: _onFilterChanged,
                  decoration: InputDecoration(
                    labelText: '検索',
                    hintText: 'ID / 物件名 / ステータス / 担当 / 種別 など',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _filterController.clear();
                        _applyFilter('');
                      },
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            Expanded(child: _buildTable()),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            icon: Icon(_showOnlyUnread ? Icons.visibility_off : Icons.visibility),
            label: Text(_showOnlyUnread ? 'すべて表示' : '未読のみ'),
            onPressed: () {
              setState(() {
                _showOnlyUnread = !_showOnlyUnread;
              });
              _applyFilters();
            },
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: "QRコード生成",
            onPressed: () {
              showGenerateLinkDialog(context, widget.companyId);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "再読み込み",
            onPressed: _onRefresh,
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    _refreshDataSource();
    return Card(
      key: _tableKey,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: dt.PaginatedDataTable2(
        wrapInCard: true,
        columns: [
          dt.DataColumn2(
            label: const Text('ID'),
            onSort: (colIndex, asc) => _onSort(colIndex, asc),
          ),
          dt.DataColumn2(
            label: const Text('物件名'),
            onSort: (colIndex, asc) => _onSort(colIndex, asc),
          ),
          dt.DataColumn2(
            label: const Text('受付種別'),
            onSort: (colIndex, asc) => _onSort(colIndex, asc),
          ),
          dt.DataColumn2(
            label: const Text('ステータス'),
            onSort: (colIndex, asc) => _onSort(colIndex, asc),
          ),
          dt.DataColumn2(
            label: const Text('担当'),
            onSort: (colIndex, asc) => _onSort(colIndex, asc),
          ),
          dt.DataColumn2(
            label: const Text('受付日'),
            onSort: (colIndex, asc) => _onSort(colIndex, asc),
          ),
        ],
        source: _dataSource,
        sortColumnIndex: _sortColumnIndex,
        sortAscending: _sortAscending,
        availableRowsPerPage: const [5, 10, 15, 20],
        rowsPerPage: _rowsPerPage,
        onRowsPerPageChanged: (newRows) {
          setState(() {
            _rowsPerPage = newRows ?? 5;
          });
        },
        showCheckboxColumn: false,
        headingRowColor: WidgetStateProperty.resolveWith(
          (states) => Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        ),
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        columnSpacing: 16,
        horizontalMargin: 12,
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalCount = _filteredInquiries.length;
    final incompleteCount = _filteredInquiries.where((i) => i.status == "未着手").length;
    final ongoingCount = _filteredInquiries.where((i) => i.status == "進行中").length;
    final doneCount = _filteredInquiries.where((i) => i.status == "完了").length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildStatCard("未着手", incompleteCount, Icons.error_outline, Colors.redAccent.shade200),
          _buildStatCard("進行中", ongoingCount, Icons.play_arrow, Colors.orange.shade300),
          _buildStatCard("完了", doneCount, Icons.check_circle_outline, Colors.green.shade400),
          _buildStatCard("合計", totalCount, Icons.list_alt, Colors.blue.shade400),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color iconBgColor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count 件',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
