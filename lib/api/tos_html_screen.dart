import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_html/flutter_html.dart';
import 'tos_service.dart'; // Adjust the import path as needed

Future<bool?> showTOSDialog({
  required BuildContext context,
  required String htmlContent,
  required String userId,
  required int latestVersion,
}) async {
  bool? result;
  await AwesomeDialog(
    context: context,
    // Use an appropriate dialog type and animation
    dialogType: DialogType.infoReverse,
    animType: AnimType.scale,
    headerAnimationLoop: false,
    // Make the dialog a bit more compact
    width: MediaQuery.of(context).size.width * 0.85,
    // Set background color to white
    dialogBackgroundColor: Colors.white,
    // Add a subtle border and rounded corners
    borderSide: BorderSide(
      color: Colors.grey.shade300,
      width: 1.5,
    ),
    buttonsBorderRadius: const BorderRadius.all(Radius.circular(8)),
    dismissOnBackKeyPress: false,
    dismissOnTouchOutside: false,
    title: '利用規約',
    titleTextStyle: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    ),
    // The body is wrapped in a container with internal padding and a max height constraint.
    body: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Html(
          data: htmlContent,
        ),
      ),
    ),
    btnCancelText: 'キャンセル',
    btnOkText: '同意する',
    btnCancelOnPress: () {
      result = false;
    },
    btnOkOnPress: () async {
      // Once the user accepts, call the backend to record the acceptance
      await TOSService.acceptDocument(
        userId: userId,
        docType: 'TOS',
        acceptedVersion: latestVersion,
      );
      result = true;
    },
  ).show();
  return result;
}
