import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'qr_code_dialog.dart';

Future<void> showGenerateLinkDialog(BuildContext context, String companyId) async {
  final buildingNameController = TextEditingController();
  final postalCodeController = TextEditingController();
  final addressController = TextEditingController();

  bool isLoading = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          // ---------------------------------------------------------------
          // 1) Fetch Address from Postal Code
          // ---------------------------------------------------------------
          Future<void> fetchAddressFromPostalCode() async {
            final postalCode = postalCodeController.text.trim();
            if (postalCode.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("郵便番号を入力してください。"),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }

            setState(() => isLoading = true);

            try {
              final url = Uri.parse(
                "http://zipcloud.ibsnet.co.jp/api/search?zipcode=$postalCode",
              );
              final resp = await http.get(url);

              if (resp.statusCode == 200) {
                final Map<String, dynamic> data = jsonDecode(resp.body);
                if (data["results"] != null && data["results"] is List) {
                  final result = data["results"][0];
                  final address1 = result["address1"] ?? "";
                  final address2 = result["address2"] ?? "";
                  final address3 = result["address3"] ?? "";
                  final fullAddress = "$address1$address2$address3"
                      .replaceAll(RegExp(r"\s+"), "");

                  addressController.text = fullAddress;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("住所を取得しました: $fullAddress")),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("住所が見つかりません。郵便番号を確認してください。"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("住所取得に失敗しました。Status: ${resp.statusCode}"),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("住所を取得中にエラー: $e"),
                  backgroundColor: Colors.redAccent,
                ),
              );
            } finally {
              setState(() => isLoading = false);
            }
          }

          // ---------------------------------------------------------------
          // 2) Generate Link via API
          // ---------------------------------------------------------------
          Future<void> generateLink() async {
            final buildingName = buildingNameController.text.trim();
            final postalCode = postalCodeController.text.trim();
            final address = addressController.text.trim();

            if (buildingName.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("建物名を入力してください。"),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }
            if (postalCode.isEmpty || address.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("郵便番号と住所を入力または取得してください。"),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }

            setState(() => isLoading = true);

            try {
              final requestBody = {
                "companyId": companyId,
                "buildingName": buildingName,
                "postalCode": postalCode,
                "address": address,
              };

              final url = Uri.parse(
                "https://9v60ngmpp4.execute-api.ap-northeast-3.amazonaws.com/TESTING/registerChatKey",
              );
              final response = await http.post(
                url,
                headers: {"Content-Type": "application/json"},
                body: jsonEncode(requestBody),
              );

              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                final tokenIdStr = data["tokenId"].toString();
                final chatToken = data["chatToken"].toString();
                final returnedCompanyId = data["companyId"].toString();

                // Build your chat link
                final chatLink =
                    "https://d3tuo4chfzzuxd.cloudfront.net/#/$returnedCompanyId/$tokenIdStr/$chatToken";

                // Parse tokenId as int
                final tokenId = int.tryParse(tokenIdStr) ?? 0;

                // Once the link is generated, pop this dialog...
                Navigator.of(dialogContext).pop();
                await showQrCodeDialog(
                  context: context,
                  tokenId: tokenId,
                  chatLink: chatLink,
                  buildingName: buildingName,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("APIエラーが発生: ${response.statusCode}"),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("API呼び出しエラー: $e"),
                  backgroundColor: Colors.redAccent,
                ),
              );
            } finally {
              setState(() => isLoading = false);
            }
          }

          // ---------------------------------------------------------------
          // Dialog Layout with Theming
          // ---------------------------------------------------------------
          return Theme(
            data: ThemeData(
              brightness: Brightness.light,
              primarySwatch: Colors.deepPurple,
              scaffoldBackgroundColor: Colors.white,
              textTheme: const TextTheme(
                bodyMedium: TextStyle(fontSize: 16.0),
                titleLarge: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
              ),
              iconTheme: const IconThemeData(
                size: 20.0,
                color: Colors.white,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade700,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16.0),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.deepPurple.shade600,
                  textStyle: const TextStyle(fontSize: 16.0),
                  side: const BorderSide(color: Colors.transparent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            child: Stack(
              children: [
                AlertDialog(
                  backgroundColor: Colors.white,
                  contentPadding: const EdgeInsets.all(20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  title: const Text(
                    "チャットリンク作成",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLabeledField(
                          label: "建物名",
                          hint: "建物名を入力",
                          controller: buildingNameController,
                        ),
                        const SizedBox(height: 12),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _buildLabeledField(
                                label: "郵便番号",
                                hint: "1234567",
                                controller: postalCodeController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.search, color: Colors.white),
                                label: const Text("住所取得"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color.fromARGB(255, 103, 80, 164),
                                ),
                                onPressed:
                                    isLoading ? null : fetchAddressFromPostalCode,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _buildLabeledField(
                          label: "住所",
                          hint: "上記から取得 / 手動入力OK",
                          controller: addressController,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  actions: [
                    // Only one action here: generate the link or close
                    ElevatedButton.icon(
                      icon: const Icon(Icons.link, color: Colors.white),
                      label: const Text("作成"),
                      onPressed: isLoading ? null : generateLink,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: const Text("閉じる"),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                // Show loading overlay if needed
                if (isLoading)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// A simple labeled field widget for DRY usage in your forms.
Widget _buildLabeledField({
  required String label,
  required String hint,
  required TextEditingController controller,
  int maxLines = 1,
  TextInputType? keyboardType,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    ],
  );
}
