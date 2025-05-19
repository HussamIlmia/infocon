import 'dart:async';
import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart' as dt;
import '../api_service.dart';
import '../components/chat_link_dialog.dart';
import '../layouts/dashboard_layout.dart';
import '../components/qr_code_dialog.dart';


class ChatLinkManagementPage extends StatefulWidget {
  final String companyId;
  const ChatLinkManagementPage({super.key, required this.companyId});

  @override
  State<ChatLinkManagementPage> createState() => _ChatLinkManagementPageState();
}

class _ChatLinkManagementPageState extends State<ChatLinkManagementPage> {
  late AsyncChatLinkDataSource _dataSource;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dataSource = AsyncChatLinkDataSource(
      companyId: widget.companyId,
      onDeleteLink: _onDeleteLink,
      onShowQrCode: (tokenId, chatLink, buildingName) async {
        await showQrCodeDialog(
          context: context,
          tokenId: tokenId,
          chatLink: chatLink,
          buildingName: buildingName,
        );
      },
    );
  }

  Future<void> _onDeleteLink(int tokenId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("確認"),
        content: const Text("このチャットリンクを削除しますか？"),
        actions: [
          TextButton(
            child: const Text("いいえ"),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            child: const Text("はい"),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final success = await ApiService.deleteChatLink(
        companyId: widget.companyId,
        tokenId: tokenId,
      );
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("削除しました。"),
            backgroundColor: Colors.green,
          ),
        );
        _dataSource.refreshDatasource();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("削除に失敗しました。"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("削除中にエラーが発生: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshTable() async {
    setState(() => _isLoading = true);
    try {
      _dataSource.refreshDatasource();
    } finally {
      // Because AsyncDataTableSource fetches data asynchronously,
      // we can't track exact finish unless we modify the data source logic.
      // We'll show a brief spinner and let the table handle final updates.
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          ignoring: _isLoading,
          child: DashboardLayout(
            selectedNavIndex: 3,
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildDataTable(colorScheme),
                  ),
                ),
                const SizedBox(height: 24),
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
          Text(
            "チャットリンク管理",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800,
            ),
          ),
          const Spacer(),
          // Add the QR icon next to the refresh button
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: "QRコード生成",
            onPressed: () {
              // Make sure showGenerateLinkDialog is imported!
              showGenerateLinkDialog(context, widget.companyId);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "再読み込み",
            onPressed: _refreshTable,
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(ColorScheme colorScheme) {
    return Card(
      elevation: 4,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: dt.AsyncPaginatedDataTable2(
        headingRowColor: WidgetStateProperty.all(
          colorScheme.primary.withValues(alpha: 0.1),
        ),
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
        columns: [
          dt.DataColumn2(
            label: const Text('トークンID'),
            size: dt.ColumnSize.S,
          ),
          dt.DataColumn2(
            label: const Text('建物名'),
            size: dt.ColumnSize.M,
          ),
          const dt.DataColumn2(
            label: Text('アクション'),
            size: dt.ColumnSize.S,
          ),
        ],
        source: _dataSource,
        rowsPerPage: 5,
        availableRowsPerPage: const [5, 10, 20],
        loading: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
        errorBuilder: (error) => Center(
          child: Text('エラーが発生: $error'),
        ),
        showCheckboxColumn: false,
        columnSpacing: 20,
        horizontalMargin: 12,
      ),
    );
  }
}

class AsyncChatLinkDataSource extends dt.AsyncDataTableSource {
  final String companyId;
  final Future<void> Function(int tokenId) onDeleteLink;
  final Future<void> Function(int tokenId, String chatLink, String buildingName)
      onShowQrCode;

  List<Map<String, dynamic>> _allItems = [];
  bool _hasLoaded = false;

  AsyncChatLinkDataSource({
    required this.companyId,
    required this.onDeleteLink,
    required this.onShowQrCode,
  });

  @override
  Future<dt.AsyncRowsResponse> getRows(int startIndex, int count) async {
    if (!_hasLoaded) {
      final items = await ApiService.fetchChatLinks(companyId);
      _allItems = items;
      _hasLoaded = true;
    }

    final endIndex = (startIndex + count).clamp(0, _allItems.length);
    final slice = _allItems.sublist(startIndex, endIndex);

    final rows = slice.map((item) {
      final tokenId = item['tokenId'] ?? 0;
      final buildingName = (item['buildingName'] ?? '').toString();
      final chatToken = (item['chatToken'] ?? '').toString();
      final chatLink =
          "https://d3tuo4chfzzuxd.cloudfront.net/#/$companyId/$tokenId/$chatToken";

      return DataRow(
        key: ValueKey(tokenId),
        cells: [
          DataCell(Text('$tokenId')),
          DataCell(Text(buildingName)),
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.qr_code, color: Colors.blue),
                  tooltip: "QRコード表示",
                  onPressed: () => onShowQrCode(tokenId, chatLink, buildingName),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: "削除",
                  onPressed: () => onDeleteLink(tokenId),
                ),
              ],
            ),
          ),
        ],
      );
    }).toList();

    return dt.AsyncRowsResponse(_allItems.length, rows);
  }

  @override
  int get selectedRowCount => 0;

  @override
  void refreshDatasource() {
    _hasLoaded = false;
    super.refreshDatasource();
  }
}
