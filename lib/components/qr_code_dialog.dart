import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';


Future<void> showQrCodeDialog({
  required BuildContext context,
  required int tokenId,
  required String chatLink,
  required String buildingName,
}) async {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "トークンID: $tokenId",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "このQRコードをスキャンしてチャットリンクにアクセスできます。",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              "建物名: $buildingName",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: SizedBox(
                width: 220,
                height: 220,
                child: QrImageView(
                  data: chatLink,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              chatLink,
              style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(120, 48),
                backgroundColor: Colors.blue.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.copy, color: Colors.white),
              label: const Text(
                "コピー",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: chatLink));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("リンクをコピーしました。")),
                );
              },
            ),

            const SizedBox(width: 8),

            // 2) PDF PREVIEW BUTTON
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(120, 48),
                backgroundColor: const Color.fromARGB(255, 205, 46, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              label: const Text(
                "PDFプレビュー",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => _previewQrCodePdf(context, chatLink, buildingName),
            ),

            const SizedBox(width: 8),

            // 3) CLOSE BUTTON
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 48),
                backgroundColor: Colors.grey.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.close, color: Colors.white),
              label: const Text("閉じる"),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> _previewQrCodePdf(BuildContext context, String chatLink, String buildingName) async {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('QRコード PDFプレビュー'),
          backgroundColor: Colors.grey.shade600,
        ),
        body: PdfPreview(
          build: (format) => _generateQrPdf(format, chatLink, buildingName),
          canChangePageFormat: true,
          canChangeOrientation: true,
          initialPageFormat: PdfPageFormat.a4,
          canDebug: false,
          allowPrinting: true,
          allowSharing: false,
          pdfFileName: 'QrCode_${DateTime.now().millisecondsSinceEpoch}.pdf',
        ),
      ),
    ),
  );
}

Future<Uint8List> _generateQrPdf(
  PdfPageFormat format,
  String data,
  String buildingName,
) async {
  final pdf = pw.Document();

  final qrImageData = await QrPainter(
    data: data,
    version: QrVersions.auto,
    gapless: false,
  ).toImageData(300);

  final qrBytes = qrImageData?.buffer.asUint8List();
  final font = await PdfGoogleFonts.notoSansJPRegular();

  pdf.addPage(
    pw.Page(
      pageFormat: format,
      build: (pw.Context context) {
        return pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (buildingName.isNotEmpty) ...[
                pw.Text(
                  buildingName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    font: font,
                  ),
                ),
                pw.SizedBox(height: 10),
              ],
              pw.Text(
                '管理会社相談AI窓口',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  font: font,
                ),
              ),
              pw.SizedBox(height: 10),
              if (qrBytes != null)
                pw.Image(
                  pw.MemoryImage(qrBytes),
                  width: 200,
                  height: 200,
                ),
              pw.SizedBox(height: 10),
              pw.Text(
                data,
                style: pw.TextStyle(fontSize: 16, font: font),
              ),
            ],
          ),
        );
      },
    ),
  );

  return pdf.save();
}
