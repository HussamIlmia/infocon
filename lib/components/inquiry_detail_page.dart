import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:info_console_app/all_models.dart';
import 'package:info_console_app/api_service.dart';

class InquiryDetailPage extends StatefulWidget {
  final String companyId;
  final String inquiryId;

  const InquiryDetailPage({
    super.key,
    required this.companyId,
    required this.inquiryId,
  });

  @override
  State<InquiryDetailPage> createState() => _InquiryDetailPageState();
}

class _InquiryDetailPageState extends State<InquiryDetailPage> {
  Map<String, dynamic>? inquiryData;
  List<RegisteredWorker> _allWorkers = [];

  final List<String> _statuses = ["未着手", "進行中", "完了"];
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = false;
  Set<String> loadingKeys = {};

  @override
  void initState() {
    super.initState();
    _fetchSingleInquiry();
    _fetchWorkers();
  }

  Future<void> _fetchSingleInquiry() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.fetchSingleInquiry(
        companyId: widget.companyId,
        inquiryId: widget.inquiryId,
      );
      if (!mounted) return;
      setState(() {
        inquiryData = data;
        if (data.containsKey('notes') && data['notes'] != null) {
          _notesController.text = data['notes'];
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("読み込み失敗: $e")),
      );
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _fetchWorkers() async {
    setState(() => _isLoading = true);
    try {
      final workers = await ApiService.fetchWorkers();
      if (!mounted) return;
      setState(() {
        _allWorkers = workers;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ワーカー情報の取得に失敗: $e")),
      );
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  /// Combined method to update status and/or assigned worker
  Future<void> _onInquiryUpdate({
    String? newStatus,
    String? newWorkerId,
  }) async {
    if (inquiryData == null) return;

    final oldStatus = inquiryData?['status'] ?? "未着手";
    final oldWorkerName = inquiryData?['assignedTo'] ?? "担当者なし";
    final oldWorkerId = inquiryData?['assignedToId'] ?? "";

    bool isStatusChange = (newStatus != null && newStatus != oldStatus);
    bool isWorkerChange = (newWorkerId != null && newWorkerId != oldWorkerId);

    if (!isStatusChange && !isWorkerChange) {
      return; // No changes
    }

    // Confirmation message
    String msg = "";
    if (isStatusChange) {
      msg = "ステータスを「$newStatus」に変更しますか？";
    } else if (isWorkerChange) {
      if (newWorkerId.isEmpty) {
        msg = "担当を「担当者なし」に変更しますか？";
      } else {
        // find the name
        final selected = _allWorkers.firstWhere(
          (w) => w.workerId == newWorkerId,
          orElse: () => RegisteredWorker(workerId: "", workerName: "担当者なし"),
        );
        msg = "担当を「${selected.workerName}」に変更しますか？";
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("確認"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("いいえ"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("はい"),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final finalStatus = isStatusChange ? newStatus : oldStatus;
      final finalWorkerId = isWorkerChange ? newWorkerId : oldWorkerId;
      String finalWorkerName = oldWorkerName;
      if (isWorkerChange) {
        if (finalWorkerId.isEmpty) {
          finalWorkerName = "担当者なし";
        } else {
          final found = _allWorkers.firstWhere(
            (w) => w.workerId == finalWorkerId,
            orElse: () => RegisteredWorker(workerId: "", workerName: "担当者なし"),
          );
          finalWorkerName = found.workerName;
        }
      }

      // Construct a minimal Inquiry object
      final inquiryModel = Inquiry(
        inquiryId: widget.inquiryId,
        status: oldStatus,
        assignedTo: oldWorkerName,
        assignedToId: oldWorkerId,
        createdAt: inquiryData?['createdAt'] ?? "",
        createdAtISO: inquiryData?['createdAtISO'] ?? "",
        inquiryType: inquiryData?['requestType'] ?? "その他",
        buildingName: inquiryData?['buildingName'] ?? "",
        isRead: false,
      );

      final success = await ApiService.updateInquiry(
        companyId: widget.companyId,
        inquiry: inquiryModel,
        newStatus: finalStatus,
        newWorkerName: finalWorkerName,
        newWorkerId: finalWorkerId,
      );

      if (!mounted) return;
      if (success) {
        setState(() {
          inquiryData?['status'] = finalStatus;
          inquiryData?['assignedTo'] = finalWorkerName;
          inquiryData?['assignedToId'] = finalWorkerId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("更新しました。")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("更新に失敗しました。")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("エラー: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateNotes() async {
    if (inquiryData == null) return;
    setState(() => _isLoading = true);
    try {
      final success = await ApiService.updateInquiryNotes(
        companyId: widget.companyId,
        inquiryId: widget.inquiryId,
        notes: _notesController.text,
      );
      if (!mounted) return;
      if (success) {
        setState(() {
          inquiryData?['notes'] = _notesController.text;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ノートを保存しました。")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ノートの保存に失敗しました。")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("エラーが発生しました: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Example to fetch a presigned URL and open it
  Future<void> _downloadDocument(String s3Key, String fileName) async {
    setState(() {
      loadingKeys.add(s3Key);
    });
    try {
      final uri = Uri.parse("YOUR_API_GATEWAY_URL/getPresignedUrl?objectKey=$s3Key");
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final presignedUrl = data["presignedUrl"];
        if (presignedUrl != null && presignedUrl.isNotEmpty) {
          final toLaunch = Uri.parse(presignedUrl);
          if (await canLaunchUrl(toLaunch)) {
            await launchUrl(toLaunch, mode: LaunchMode.externalApplication);
          } else {
            throw "Could not launch $presignedUrl";
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("取得できません: $fileName")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("エラーが発生しました: $fileName")),
      );
    } finally {
      if (mounted) {
        setState(() {
          loadingKeys.remove(s3Key);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && inquiryData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("受け付け詳細"),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (inquiryData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("受け付け詳細"),
          centerTitle: true,
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: _fetchSingleInquiry,
            child: const Text("再読み込み"),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text("詳細 #${widget.inquiryId}"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                _buildTopCard(),
                _buildChatBubbleCard(),
                _buildNotesCard(),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildTopCard() {
    final String rawStatus = inquiryData?['status'] ?? "未着手";
    final String assignedId   = inquiryData?['assignedToId'] ?? "";
    final String rawRequestType = inquiryData?['requestType'] ?? "other";
    final String createdAt = inquiryData?['createdAt'] ?? "N/A";
    final List docs = inquiryData?['assets'] as List? ?? [];

    String displayType;
    switch (rawRequestType) {
      case "moveOut":
        displayType = "退去";
        break;
      case "maintenance":
        displayType = "修理・保守";
        break;
      default:
        displayType = "その他";
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  "ステータス: ",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                DropdownButton<String>(
                  value: rawStatus,
                  items: _statuses.map((s) {
                    return DropdownMenuItem<String>(
                      value: s,
                      child: Text(s),
                    );
                  }).toList(),
                  onChanged: (newVal) async {
                    if (newVal != null && newVal != rawStatus) {
                      await _onInquiryUpdate(newStatus: newVal);
                    }
                  },
                ),
                const Spacer(),
                const Text(
                  "担当: ",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                // Worker dropdown by ID
                DropdownButton<String>(
                  value: assignedId, // <--- use the worker ID as the value
                  items: [
                    const DropdownMenuItem<String>(
                      value: "",
                      child: Text("担当者なし"),
                    ),
                    ..._allWorkers.map((w) {
                      return DropdownMenuItem<String>(
                        value: w.workerId,
                        child: Text(w.workerName),
                      );
                    }),
                  ],
                  onChanged: (newWorkerId) async {
                    if (newWorkerId != null && newWorkerId != assignedId) {
                      await _onInquiryUpdate(newWorkerId: newWorkerId);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("種別: $displayType", style: const TextStyle(fontSize: 13)),
                Text("受付日: $createdAt", style: const TextStyle(fontSize: 13)),
              ],
            ),
            const Divider(height: 18, thickness: 1),
            const Text(
              "ドキュメント",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            if (docs.isEmpty)
              const Text("関連ドキュメントはありません。", style: TextStyle(fontSize: 13, color: Colors.black54))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final String fileName = doc['filename'] ?? "Unknown File";
                  final String s3Key = doc['s3Key'] ?? "";
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 0,
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(fileName, style: const TextStyle(fontSize: 13)),
                    trailing: IconButton(
                      icon: loadingKeys.contains(s3Key)
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      onPressed: () => _downloadDocument(s3Key, fileName),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubbleCard() {
    final messages = inquiryData?['messages'] as List? ?? [];
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("チャット履歴", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(height: 4),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                if (msg is Map<String, dynamic>) {
                  return _buildMessageBubble(msg);
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final String sender = msg['sender'] ?? '';
    final String text = msg['text'] ?? '';
    final bool isUser = (sender == 'ユーザー');

    final Color bubbleColor = isUser ? const Color(0xFFDCF8C6) : const Color(0xFFE8EAED);
    final Alignment align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final BorderRadius borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: Radius.circular(isUser ? 12 : 0),
      bottomRight: Radius.circular(isUser ? 0 : 12),
    );

    return Container(
      alignment: align,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
        decoration: BoxDecoration(color: bubbleColor, borderRadius: borderRadius),
        child: SelectableText(
          text,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("社員備考", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "このインクワイアリのメモを入力してください...",
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _updateNotes,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text("保存", style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
