import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../all_models.dart';
import '../api_service.dart';
import '../layouts/dashboard_layout.dart';

class WorkerDocumentPage extends StatefulWidget {
  final String companyId;
  const WorkerDocumentPage({super.key, required this.companyId});

  @override
  State<WorkerDocumentPage> createState() => _WorkerDocumentPageState();
}

class _WorkerDocumentPageState extends State<WorkerDocumentPage> {
  List<DocumentRow> _allDocuments = [];
  List<DocumentRow> _filteredDocuments = [];

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  final Set<String> _downloadingKeys = {};

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final documents = await ApiService.listHoukokushoDocuments(widget.companyId);
      _allDocuments = documents;
      _filteredDocuments = List.from(documents);
    } catch (e) {
      _errorMessage = "ドキュメントの取得に失敗しました: $e";
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterDocuments(String query) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) {
      _filteredDocuments = List.from(_allDocuments);
    } else {
      _filteredDocuments = _allDocuments.where((doc) {
        final matchName = doc.workerName.toLowerCase().contains(text);
        final matchChat = doc.chatId.toLowerCase().contains(text);
        final matchFile = doc.filename.toLowerCase().contains(text);
        return matchName || matchChat || matchFile;
      }).toList();
    }
    setState(() {});
  }

  Future<void> _downloadDocument(DocumentRow doc) async {
    final s3Key = doc.s3Key;
    final fileName = doc.filename;
    if (s3Key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("無効なS3キー: $fileName")),
      );
      return;
    }
    setState(() {
      _downloadingKeys.add(s3Key);
    });
    try {
      final presignedUrl = await ApiService.getPresignedUrl(s3Key);
      final urlToLaunch = Uri.parse(presignedUrl);
      if (await canLaunchUrl(urlToLaunch)) {
        await launchUrl(urlToLaunch, mode: LaunchMode.externalApplication);
      } else {
        throw "URLを開けませんでした: $presignedUrl";
      }
    } catch (e) {
      debugPrint("Error fetching presigned URL for $fileName: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("エラーが発生しました: $fileName")),
      );
    } finally {
      setState(() {
        _downloadingKeys.remove(s3Key);
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    return "${dt.year}/${dt.month.toString().padLeft(2, '0')}"
           "/${dt.day.toString().padLeft(2, '0')} "
           "${dt.hour.toString().padLeft(2, '0')}"
           ":${dt.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _onRefresh() async {
    _searchController.clear();
    _filterDocuments('');
    await _fetchDocuments();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          ignoring: _isLoading,
          child: DashboardLayout(
            selectedNavIndex: 2, 
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
                    child: _buildBody(),
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
            "作業員生成書類",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 260,
            child: _buildSearchBar(),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "再読み込み",
            onPressed: _onRefresh,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: TextField(
        controller: _searchController,
        onChanged: _filterDocuments,
        decoration: InputDecoration(
          labelText: "検索",
          hintText: "作業員名、チャットID、ファイル名など",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterDocuments('');
                  },
                )
              : null,
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
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_filteredDocuments.isEmpty) {
      return const Center(
        child: Text("該当のドキュメントがありません。"),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                    ),
                    headingTextStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    columns: const [
                      DataColumn(label: Text("作業員名")),
                      DataColumn(label: Text("チャットID")),
                      DataColumn(label: Text("ファイル名")),
                      DataColumn(label: Text("最終更新日時")),
                      DataColumn(label: Text("ダウンロード")),
                    ],
                    rows: _filteredDocuments.map((doc) {
                      final isDownloading = _downloadingKeys.contains(doc.s3Key);
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(doc.workerName.isNotEmpty
                                ? doc.workerName
                                : doc.workerId),
                          ),
                          DataCell(Text(doc.chatId)),
                          DataCell(Text(doc.filename)),
                          DataCell(
                            Text(
                              doc.lastModified != null
                                  ? _formatDateTime(doc.lastModified!)
                                  : "不明",
                            ),
                          ),
                          DataCell(
                            isDownloading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.download),
                                    onPressed: () => _downloadDocument(doc),
                                  ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
