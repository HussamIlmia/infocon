import 'dart:convert';
import 'package:http/http.dart' as http;

class TOSService {
  static const String baseUrl =
      "https://9v60ngmpp4.execute-api.ap-northeast-3.amazonaws.com/TESTING";
  // Checks if user needs to accept the document
  static Future<Map<String, dynamic>> checkDocument({
    required String appId,
    required String userId,
    required String docType,
  }) async {
    final uri = Uri.parse('$baseUrl/checkDocument?appId=$appId&userId=$userId&docType=$docType');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to check TOS: ${response.body}');
    }
  }

  // Accepts the document
  static Future<void> acceptDocument({
    required String userId,
    required String docType,
    required int acceptedVersion,
  }) async {
    final uri = Uri.parse('$baseUrl/acceptDocument');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'docType': docType,
        'acceptedVersion': acceptedVersion,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to accept TOS: ${response.body}');
    }
  }
}
