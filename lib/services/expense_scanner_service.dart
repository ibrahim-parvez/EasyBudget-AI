import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image/image.dart' as img;

class ExpenseScannerService {
  ExpenseScannerService._();
  static final ExpenseScannerService instance = ExpenseScannerService._();

  /// Scans a receipt and extracts JSON data
  Future<Map<String, dynamic>?> scanExpense(BuildContext context) async {
    try {
      final dynamic result =
          await FlutterDocScanner().getScannedDocumentAsImages(page: 1);

      if (result == null || result is! List || result.isEmpty) {
        debugPrint("❌ No documents scanned");
        return null;
      }

      // Only take the first scanned page
      final File scannedFile = File(result.first.toString());

      // Ensure image is JPEG for Gemini
      final bytes = await scannedFile.readAsBytes();
      final img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint("❌ Could not decode scanned image");
        return null;
      }
      final jpegBytes = img.encodeJpg(image, quality: 90);
      final base64Image = base64Encode(jpegBytes);

      return await _callGemini(base64Image);
    } catch (e) {
      debugPrint("❌ scanExpense error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> _callGemini(String base64Image) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint("❌ No Gemini API Key found");
      return null;
    }

    final String url =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey";

    final prompt = """
                  You are an expense extraction assistant. 
                  Extract details from this receipt image and return ONLY a valid JSON object with these keys:

                  - amount: total amount spent (number, not string)
                  - category: simple category like Groceries, Transport, Shopping, Utilities, etc.
                  - date: receipt date in YYYY-MM-DD format
                  - location: store/merchant name (string)
                  - description: short text summary of the purchase (string)

                  Return ONLY the JSON object, no explanations, no markdown.
                  """;

    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt},
              {"inlineData": {"mimeType": "image/jpeg", "data": base64Image}}
            ]
          }
        ]
      }),
    );

    if (response.statusCode != 200) {
      debugPrint("❌ Gemini API error: ${response.body}");
      return null;
    }

    try {
      final data = jsonDecode(response.body);

      // Gemini sometimes returns multiple candidates
      final text = (data['candidates'] as List)
          .map((c) => c['content']['parts'][0]['text'].toString())
          .firstWhere((t) => t.trim().isNotEmpty, orElse: () => "");

      if (text.isEmpty) {
        debugPrint("❌ Gemini returned empty content: ${response.body}");
        return null;
      }

      // Remove ```json or ``` fences if present
      String cleaned = text.trim();
      if (cleaned.startsWith("```")) {
        final lines = cleaned.split('\n');
        if (lines.first.startsWith("```")) lines.removeAt(0);
        if (lines.isNotEmpty && lines.last.startsWith("```")) lines.removeLast();
        cleaned = lines.join('\n').trim();
      }

      final Map<String, dynamic> parsed = jsonDecode(cleaned);
      return parsed;
    } catch (e) {
      debugPrint("❌ Error parsing Gemini response: $e\nRaw: ${response.body}");
      return null;
    }
  }
}
