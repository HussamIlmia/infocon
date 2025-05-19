class Inquiry {
  final String inquiryId;
  final String buildingName;
  final String inquiryType;

  String status;
  String assignedTo;     // The worker's display name
  String assignedToId;   // The worker's unique ID (new field)

  final String createdAt;
  final String createdAtISO;
  bool isRead;
  bool isNew;

  Inquiry({
    required this.inquiryId,
    required this.buildingName,
    required this.inquiryType,
    required this.status,
    required this.assignedTo,
    required this.assignedToId,   // <-- new
    required this.createdAt,
    required this.createdAtISO,
    this.isRead = false,
    this.isNew = false,
  });
}

class RegisteredWorker {
  final String workerId;
  final String workerName;

  RegisteredWorker({
    required this.workerId,
    required this.workerName,
  });
}

class DocumentRow {
  final String workerId;
  final String workerName;
  final String chatId;
  final String s3Key;
  final String filename;
  final DateTime? lastModified;

  DocumentRow({
    required this.workerId,
    required this.workerName,
    required this.chatId,
    required this.s3Key,
    required this.filename,
    this.lastModified,
  });

  factory DocumentRow.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json["lastModified"] != null) {
      try {
        parsedDate = DateTime.parse(json["lastModified"]);
      } catch (_) {
        parsedDate = null;
      }
    }
    return DocumentRow(
      workerId: json["workerId"] ?? "",
      workerName: json["workerName"] ?? "",
      chatId: json["chatId"] ?? "",
      s3Key: json["s3Key"] ?? "",
      filename: json["filename"] ?? "houkokusho.xlsx",
      lastModified: parsedDate,
    );
  }
}
