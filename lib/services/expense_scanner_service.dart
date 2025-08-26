import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ExpenseScannerService {
  // Singleton
  ExpenseScannerService._();
  static final ExpenseScannerService instance = ExpenseScannerService._();

  final ImagePicker _picker = ImagePicker();

  /// Opens picker with options (camera or gallery)
  Future<Map<String, dynamic>?> scanExpense(BuildContext context) async {
    try {
      final ImageSource? source = await _chooseSource(context);
      if (source == null) return null;

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );

      if (image == null) return null;

      // Convert image to base64
      final bytes = await File(image.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      // Call Gemini
      final result = await _callGemini(base64Image);

      return result;
    } catch (e) {
      debugPrint("scanExpense error: $e");
      return null;
    }
  }

  /// Show bottom sheet to pick source
  Future<ImageSource?> _chooseSource(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Take Photo"),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Choose from Gallery"),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Calls Gemini API with receipt image
  Future<Map<String, dynamic>?> _callGemini(String base64Image) async {
  final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    debugPrint("❌ Error. No Key Found");
    return null;
  }

  final String url =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey";

  final response = await http.post(
    Uri.parse(url),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "contents": [
        {
          "parts": [
            {
              "text": """
                You are an expense extraction assistant. 
                Extract details from this receipt image and return ONLY a valid JSON object with these keys:

                - amount: total amount spent (number, not string)
                - category: simple category like Groceries, Transport, Shopping, Utilities, etc.
                - date: receipt date in YYYY-MM-DD format
                - location: store/merchant name (string)
                - description: short text summary of the purchase (string)

                Return ONLY the JSON object, no explanations, no markdown.
                """
            },
            {
              "inlineData": {
                "mimeType": "image/jpeg",
                "data": base64Image,
              }
            }
          ]
        }
      ]
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    try {
      String text = data['candidates'][0]['content']['parts'][0]['text'];

      // --- sanitize in case Gemini wraps with ```json ... ```
      text = text.trim();
      if (text.startsWith("```")) {
        final lines = text.split('\n');
        if (lines.first.startsWith("```")) lines.removeAt(0);
        if (lines.isNotEmpty && lines.last.startsWith("```")) lines.removeLast();
        text = lines.join('\n').trim();
      }

      final parsed = jsonDecode(text);
      return parsed;
    } catch (e) {
      debugPrint("Error parsing Gemini response: $e\nRaw text: ${response.body}");
      return null;
    }
  } else {
    debugPrint("Gemini API error: ${response.body}");
    return null;
  }
}
}