import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/expense.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'token_storage.dart';
import 'dart:math';
import '../config/api_config.dart';

class ExpenseService {
  // Replace with your actual key if not using --dart-define
  static const _apiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const _modelId = 'gpt-4o-mini';
  
  // Update this IP if you are on a real device (use your PC's local IP, not localhost)
  static String get _backendUrl => '${ApiConfig.baseUrl}/api/spending/add-receipt/';
  
  final _storage = const FlutterSecureStorage();

  Future<Expense?> processReceipt(Uint8List imageBytes) async {
    if (_apiKey.isEmpty) {
      print("Error: API Key is missing. Ensure you run flutter run --dart-define=OPENAI_API_KEY=sk-...");
      throw Exception("API Key is missing.");
    }

    String base64Image = base64Encode(imageBytes);

    final promptText = 
      "Analyze this receipt. Return ONLY a JSON object. "
      "Categorize this expense into EXACTLY one of these labels: "
      "rent, utilities, entertainment, groceries, transportation, healthcare, savings, other. "
      "Format: {'merchant': 'string', 'amount': number, 'category': 'string', 'date': 'YYYY-MM-DD'} "
      "If the date is missing on the receipt, use today's date.";

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model": _modelId,
          "response_format": {"type": "json_object"},
          "messages": [
            {
              "role": "user",
              "content": [
                {"type": "text", "text": promptText},
                {
                  "type": "image_url",
                  "image_url": {"url": "data:image/jpeg;base64,$base64Image"}
                }
              ]
            }
          ],
          "max_tokens": 500,
        }),
      );

      if (response.statusCode != 200) {
        print("OpenAI Error: ${response.body}");
        return null;
      }

      final data = jsonDecode(response.body);
      String content = data['choices'][0]['message']['content'];
      
      final cleanJson = _cleanJsonString(content);
      final Map<String, dynamic> jsonData = jsonDecode(cleanJson);
      return Expense.fromJson(jsonData);
    } catch (e) {
      print("Processing Error: $e");
      return null;
    }
  }

  // Backfill Logic (Uses standard DateTime strings, no intl)
  Future<int> generateAndSaveBackfill(String accountType) async {
    String prompt;
    String today = DateTime.now().toIso8601String().split('T')[0];
    
    if (accountType == 'Savings') {
      prompt = '''
        Generate 5 realistic transactions for a Savings Account over the last 60 days.
        Return a JSON object with a key "transactions" containing a list.
        Inner Keys: "amount" (float), "category", "date" (YYYY-MM-DD).
        Category must be EXACTLY: "savings".
        Dates must be distinct and within the last 60 days relative to $today.
      ''';
    } else {
      final personas = ["foodie", "fitness enthusiast", "tech lover", "parent", "traveler"];
      final randomPersona = personas[Random().nextInt(personas.length)];

      prompt = '''
        Generate 15 realistic spending transactions for a user who is a $randomPersona.
        Return a JSON object with a key "transactions" containing a list.
        Inner Keys: "amount" (float), "category", "date" (YYYY-MM-DD).
        Categories: rent, utilities, entertainment, groceries, transportation, healthcare, other.
        Spread dates over last 30 days relative to $today.
        AVOID duplicate category+date pairs.
      ''';
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_apiKey'},
        body: jsonEncode({
          "model": _modelId,
          "response_format": {"type": "json_object"}, 
          "messages": [{"role": "user", "content": prompt}]
        }),
      );

      if (response.statusCode != 200) throw Exception("OpenAI Error");

      final data = jsonDecode(response.body);
      String content = data['choices'][0]['message']['content'];
      final cleanJson = _cleanJsonString(content);
      final parsedData = jsonDecode(cleanJson);

      List<dynamic> transactions;
      if (parsedData.containsKey('transactions')) {
        transactions = parsedData['transactions'];
      } else {
        transactions = parsedData.values.firstWhere((v) => v is List, orElse: () => []);
      }

      int successCount = 0;
      for (var t in transactions) {
        try {
          await saveToDatabase(
            amount: (t['amount'] as num).toDouble(),
            category: t['category'],
            date: t['date'],
          );
          successCount++;
        } catch (e) {
          print("Skipped: $e");
        }
      }
      return successCount;

    } catch (e) {
      print("Failed to generate history: $e");
      rethrow;
    }
  }

  String _cleanJsonString(String text) {
    text = text.replaceAll('```json', '').replaceAll('```', '').trim();
    int startIndex = text.indexOf('{');
    int endIndex = text.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1) {
      text = text.substring(startIndex, endIndex + 1);
    }
    return text;
  }

  // Database Save Logic (Handles 401 Logout and Date Formatting)
  Future<void> saveToDatabase({
    required double amount,
    required String category,
    String? date, 
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) throw Exception("User is not logged in");

    // Use passed date OR today's date (formatted YYYY-MM-DD)
    final finalDate = date ?? DateTime.now().toIso8601String().split('T')[0];

    try {
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'category': category.toLowerCase(),
          'amount': amount,
          'date': finalDate, 
        }),
      );

      if (response.statusCode == 401) {
        await TokenStorage.clear();
        throw Exception("Unauthorized: Please log in again.");
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Success! Saved $category - $amount on $finalDate");
      } else {
        throw Exception("Failed to save: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }
}