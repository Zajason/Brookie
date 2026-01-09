import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

class ReceiptProcessor {
  // This reads the key from the build flag we will use later
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  Future<String> classifyReceipt(Uint8List imageBytes) async {
    if (_apiKey.isEmpty) return "Error: API Key is missing";

    // Use Gemini 2.0 Flash for speed and free tier
    final model = GenerativeModel(
      model: 'gemini-2.0-flash', 
      apiKey: _apiKey
    );

    final prompt = TextPart(
      "Analyze this receipt. Return a JSON object with: "
      "merchant_name, total_amount, date, and category (Food, Entertainment, Utilities, or Other)."
    );
    
    final imagePart = DataPart('image/jpeg', imageBytes);

    final response = await model.generateContent([
      Content.multi([prompt, imagePart])
    ]);

    return response.text ?? "No data extracted";
  }
}