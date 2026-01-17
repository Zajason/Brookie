import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/expense.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'token_storage.dart';
import '../config/api_config.dart';

class ExpenseService {
  // WE REMOVED THE API KEY FROM HERE. 
  // The phone is now "dumb" - it just sends images to the server.

  // 1. New Endpoint for Analysis
  static String get _analyzeUrl => '${ApiConfig.baseUrl}/api/analyze-receipt/';
  
  // 2. Existing Endpoint for Saving
  static String get _saveUrl => '${ApiConfig.baseUrl}/api/spending/add-receipt/';

  final _storage = const FlutterSecureStorage();

  Future<Expense?> processReceipt(Uint8List imageBytes) async {
    // 1. Get the User's Django Token (Required to talk to your server)
    final token = await TokenStorage.getAccessToken();
    if (token == null) {
      print("Error: User is not logged in.");
      return null; // Or throw exception
    }

    // 2. Convert Image to Base64 to send over network
    String base64Image = base64Encode(imageBytes);

    try {
      print("Sending image to backend for analysis...");
      
      // 3. Send to YOUR Django Backend (Not Gemini directly)
      final response = await http.post(
        Uri.parse(_analyzeUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Use Django Token
        },
        body: jsonEncode({
          "image": base64Image, // We just send the image string
        }),
      );

      // Handle Token Expiry
      if (response.statusCode == 401) {
        print("Token expired.");
        await TokenStorage.clear();
        throw Exception("Unauthorized");
      }

      if (response.statusCode != 200) {
        print("Backend Analysis Failed: ${response.body}");
        return null;
      }

      print("Backend Response: ${response.body}");

      // 4. Parse the result directly
      // The backend now does the heavy lifting (cleaning JSON, etc.)
      final jsonData = jsonDecode(response.body);
      return Expense.fromJson(jsonData);

    } catch (e) {
      print("Processing Error: $e");
      return null;
    }
  }

  Future<void> saveToDatabase({
    required double amount,
    required String category,
    String? merchant, // Added this to match your request
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) throw Exception("User is not logged in");

    try {
      final response = await http.post(
        Uri.parse(_saveUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'category': category.toLowerCase(),
          'amount': amount,
          // 'merchant': merchant, // Uncomment if backend supports it
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Success! Saved to Django.");
      } else {
        throw Exception("Failed to save: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Connection Exception: $e");
      rethrow;
    }
  }

  /* NOTE: generateAndSaveBackfill is commented out because we removed the 
   Gemini API Key from the frontend. To fix this feature, you would need 
   to create a backend endpoint like '/api/generate-backfill/' and move 
   the prompt logic to Django, similar to how we moved the receipt analysis.
  */
  Future<int> generateAndSaveBackfill(String accountType) async {
    print("Backfill generation requires backend implementation.");
    return 0; 
  }
}