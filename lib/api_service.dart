import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:info_console_app/all_models.dart';

class ApiService {
  /// The base URL for your API Gateway endpoints.
  static const String _baseUrl =
      "https://9v60ngmpp4.execute-api.ap-northeast-3.amazonaws.com/TESTING";

  // -------------------------------------------------------------------------
  // WORKERS
  // -------------------------------------------------------------------------
  /// Fetches the list of workers from the `/listWorkers` endpoint.
  static Future<List<RegisteredWorker>> fetchWorkers() async {
    final String url = "$_baseUrl/listWorkers";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) {
        return RegisteredWorker(
          workerId: item["workerId"] ?? "N/A",
          workerName: item["workerName"] ?? "",
        );
      }).toList();
    } else {
      throw Exception("Failed to fetch workers. "
          "Status: ${response.statusCode}, Body: ${response.body}");
    }
  }

  static Future<bool> registerWorker({
    required String workerName,
    required String password,
    required String parentCompanyId,
  }) async {
    final String url = "$_baseUrl/registerWorker";
    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "workerName": workerName,
        "password": password,
        "parentCompanyId": parentCompanyId,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  static Future<bool> deleteWorker(String workerId) async {
    final String url = "$_baseUrl/deleteWorker";
    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"workerId": workerId}),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // INQUIRIES (Multiple + Single)
  // -------------------------------------------------------------------------
  static Future<List<Inquiry>> fetchInquiries(String companyId) async {
    final String url = "$_baseUrl/getInquiries?companyId=$companyId";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) {
        final rawRequestType = item["requestType"] ?? "other";
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

        final rawStatus = item["status"] ?? "未着手";

        // Worker name
        final rawAssigned =
            (item["assignedTo"] == null || (item["assignedTo"] as String).isEmpty)
                ? "担当者なし"
                : item["assignedTo"];

        // NEW OR CHANGED: Worker ID (if not present, use empty string)
        final rawAssignedId = item["assignedToId"] ?? "";

        final buildingName = item["buildingName"] ?? "N/A";
        bool isRead =
            item.containsKey("isRead") ? item["isRead"] as bool : false;

        return Inquiry(
          inquiryId: item["inquiryId"] ?? "N/A",
          status: rawStatus,
          assignedTo: rawAssigned,
          assignedToId: rawAssignedId,   // <-- NEW
          createdAt: item["createdAt"] ?? "N/A",
          inquiryType: displayType,
          buildingName: buildingName,
          isRead: isRead,
          createdAtISO: item["createdAtISO"] ?? "N/A",
          isNew: false,
        );
      }).toList();
    } else {
      throw Exception("Failed to fetch inquiries. "
          "Status: ${response.statusCode}, Body: ${response.body}");
    }
  }

  static Future<Map<String, dynamic>> fetchSingleInquiry({
    required String companyId,
    required String inquiryId,
  }) async {
    final String url = "$_baseUrl/getInquiry?companyId=$companyId&inquiryId=$inquiryId";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) {
        return _unpackDynamoDbMap(raw);
      } else {
        throw Exception("Unexpected response format for single inquiry.");
      }
    } else {
      throw Exception("Failed to fetch single inquiry. "
          "Status: ${response.statusCode}, Body: ${response.body}");
    }
  }

  /// Updates an existing inquiry using the `/updateInquiry` endpoint.
static Future<bool> updateInquiry({
  required String companyId,
  required Inquiry inquiry,
  required String newStatus,
  required String newWorkerName, // the worker’s display name
  required String newWorkerId,   // the worker’s unique ID
  bool? isRead,                  // optional; if provided, must be a boolean
}) async {
  final String url = "$_baseUrl/updateInquiry";

  // Explicitly define the map as Map<String, dynamic>
  final Map<String, dynamic> requestBody = {
    "inquiryId": inquiry.inquiryId,
    "companyId": companyId,
    "status": newStatus,
    "assignedTo": newWorkerName,
    "assignedToId": newWorkerId,
  };

  // Add isRead as a boolean if provided
  if (isRead != null) {
    requestBody["isRead"] = isRead;
  }

  // Optionally log the request body for debugging purposes
  // print("Request Body: $requestBody");

  final response = await http.post(
    Uri.parse(url),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode(requestBody),
  );

  if (response.statusCode == 200) {
    return true;
  } else {
    // Optionally log the response for debugging purposes
    // print("Update failed: ${response.statusCode}, Body: ${response.body}");
    return false;
  }
}

  // -------------------------------------------------------------------------
  // NOTES
  // -------------------------------------------------------------------------
  static Future<bool> updateInquiryNotes({
    required String companyId,
    required String inquiryId,
    required String notes,
  }) async {
    final String url = "$_baseUrl/updateInquiryNotes";
    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "inquiryId": inquiryId,
        "companyId": companyId,
        "notes": notes,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // CHAT LINKS
  // -------------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> fetchChatLinks(String companyId) async {
    final String url = "$_baseUrl/listChatLinks?companyId=$companyId";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonBody = jsonDecode(response.body);
      if (jsonBody.containsKey("Items") && jsonBody["Items"] is List) {
        final items = jsonBody["Items"] as List;
        return items.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        return [];
      }
    } else {
      throw Exception("Failed to fetch chat links. "
          "Status: ${response.statusCode}, Body: ${response.body}");
    }
  }

  static Future<bool> deleteChatLink({
    required String companyId,
    required int tokenId,
  }) async {
    final String url = "$_baseUrl/deleteChatLink?companyId=$companyId&tokenId=$tokenId";
    final response = await http.delete(Uri.parse(url));
    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // DOCUMENTS (Excel / Houkokusho)
  // -------------------------------------------------------------------------
  static Future<List<DocumentRow>> listHoukokushoDocuments(String companyId) async {
    final String url = "$_baseUrl/listHoukokushoDocuments?companyId=$companyId";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> rawList = jsonDecode(response.body);
      return rawList.map((jsonItem) {
        return DocumentRow.fromJson(jsonItem);
      }).toList();
    } else {
      throw Exception("Failed to load documents. "
          "Status: ${response.statusCode}, Body: ${response.body}");
    }
  }

  static Future<String> getPresignedUrl(String objectKey) async {
    final String url = "$_baseUrl/getPresignedUrl?objectKey=$objectKey";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final String presignedUrl = data["presignedUrl"] ?? "";
      if (presignedUrl.isEmpty) {
        throw Exception("Empty presignedUrl in response");
      }
      return presignedUrl;
    } else {
      throw Exception("Failed to get presigned URL. "
          "Status: ${response.statusCode}, Body: ${response.body}");
    }
  }

  // -------------------------------------------------------------------------
  // INTERNAL HELPERS (to unpack DynamoDB values if needed)
  // -------------------------------------------------------------------------
  static Map<String, dynamic> _unpackDynamoDbMap(Map<String, dynamic> dynamoMap) {
    final Map<String, dynamic> result = {};
    dynamoMap.forEach((key, value) {
      result[key] = _unpackDynamoDbValue(value);
    });
    return result;
  }

  static dynamic _unpackDynamoDbValue(dynamic value) {
    if (value is Map<String, dynamic> && value.length == 1) {
      if (value.containsKey('S')) {
        return value['S'];
      } else if (value.containsKey('N')) {
        final numStr = value['N'];
        if (numStr.contains('.')) {
          return double.tryParse(numStr) ?? numStr;
        } else {
          return int.tryParse(numStr) ?? numStr;
        }
      } else if (value.containsKey('BOOL')) {
        return value['BOOL'] == true;
      } else if (value.containsKey('M')) {
        return _unpackDynamoDbMap(value['M'] as Map<String, dynamic>);
      } else if (value.containsKey('L')) {
        final listVal = value['L'] as List;
        return listVal.map(_unpackDynamoDbValue).toList();
      }
    }
    if (value is List) {
      return value.map(_unpackDynamoDbValue).toList();
    } else if (value is Map<String, dynamic>) {
      final mapVal = <String, dynamic>{};
      value.forEach((k, v) {
        mapVal[k] = _unpackDynamoDbValue(v);
      });
      return mapVal;
    }
    return value;
  }
}
