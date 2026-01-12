import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../models/expense.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'token_storage.dart';
import 'dart:math';
import '../config/api_config.dart' ;

class ExpenseService {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  
  // Replace with your local backend IP (10.0.2.2 for Android Emulator)
  static String get _backendUrl => '${ApiConfig.baseUrl}/api/spending/add-receipt/'; 

  final _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: _apiKey);

  Future<Expense?> processReceipt(Uint8List imageBytes) async {
  if (_apiKey.isEmpty) throw Exception("API Key is missing.");

  final prompt = TextPart(
  "Analyze this receipt. Return ONLY a JSON object. "
  "Categorize this expense into EXACTLY one of these labels: "
  "Rent, Utilities, Entertainment, Groceries, Transportation, Savings, Healthcare, or Other. "
  "Format: {'merchant': 'string', 'amount': number, 'category': 'string', 'date': 'YYYY-MM-DD'}"
);
  
  final imagePart = DataPart('image/jpeg', imageBytes);
  
  try {
    final response = await _model.generateContent([
      Content.multi([prompt, imagePart])
    ]);

    String? text = response.text;
    if (text == null) return null;

    print("RAW AI RESPONSE: $text"); // This helps us see what the AI sent

    // --- NEW CLEANING LOGIC ---
    // Remove Markdown code blocks if present
    text = text.replaceAll('```json', '').replaceAll('```', '').trim();
    
    // Find the first '{' and last '}' to ignore any extra conversational text
    int startIndex = text.indexOf('{');
    int endIndex = text.lastIndexOf('}');
    
    if (startIndex != -1 && endIndex != -1) {
      text = text.substring(startIndex, endIndex + 1);
    }

    // Convert single quotes to double quotes (Gemini sometimes uses single)
    // This is a simple fix for the error you just saw
    text = text.replaceAll("'", '"');
    
    final Map<String, dynamic> jsonData = jsonDecode(text);
    final expense = Expense.fromJson(jsonData);

    return expense;
  } catch (e) {
    print("Processing Error: $e");
    return null;
  }
}

  Future<void> _saveToBackend(Expense expense) async {
    try {
      await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(expense.toJson()),
      );
    } catch (e) {
      print("Backend error: $e");
    }
  }

  Future<void> debugListAvailableModels() async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$_apiKey');

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("------------- AVAILABLE MODELS -------------");
        for (var m in data['models']) {
          // We only care about models that support "generateContent"
          if (m['supportedGenerationMethods'].contains('generateContent')) {
             print("Model Name: ${m['name']}");
          }
        }
        print("--------------------------------------------");
      } else {
        print("Failed to list models: ${response.body}");
      }
    } catch (e) {
      print("Error listing models: $e");
    }
  }

  final _storage = const FlutterSecureStorage();

  Future<void> saveToDatabase({
    required String merchant,
    required double amount,
    required String category,
  }) async {
    // 1. Get the token securely from your storage helper
    final token = await TokenStorage.getAccessToken();

    if (token == null) {
      print("Error: No access token found. User might need to log in.");
      throw Exception("User is not logged in");
    }

    print("Token found! Sending data to Django...");

    try {
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Attach the token
        },
        body: jsonEncode({
          'category': category.toLowerCase(), // Ensure lowercase for Django
          'amount': amount,
          // 'merchant': merchant, // Uncomment if you add a Merchant field to Django
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Success! Receipt saved to Django.");
        print("Server Response: ${response.body}");
      } else {
        print("Backend Error: ${response.statusCode}");
        print("Response Body: ${response.body}");
        throw Exception("Failed to save to backend: ${response.statusCode}");
      }
    } catch (e) {
      print("Connection Exception: $e");
      rethrow;
    }
  }

  // Generates realistic past transactions using Gemini and saves them to Django
  Future<int> generateAndSaveBackfill(String accountType) async {
    String prompt;
    // --- LOGIC SPLIT BASED ON BUTTON PRESSED ---
    if (accountType == 'Savings') {
      // SAVINGS: Low activity, money coming IN or transfers
      prompt = '''
        Generate 4 realistic transactions for a Savings Account.
        Return ONLY a raw JSON list.
        Keys: "merchant", "amount" (float), "category".
        
        Transactions should be things like: "Interest Payment", "Monthly Deposit", "Transfer from Checking", "Goal Contribution".
        Category must be exactly: "savings".
        Amounts should be between 20.00 and 2000.00.
      ''';
    } else {
      // CHECKING: High activity, personas, spending money
      final personas = [
        "a foodie who eats at restaurants constantly",
        "a fitness enthusiast who buys supplements and gym gear",
        "a tech lover who buys gadgets and subscriptions",
        "a parent buying lots of groceries and kids' stuff",
        "a traveler with hotel and airline expenses",
        "a student with small, frugal transactions",
      ];
      final randomPersona = personas[Random().nextInt(personas.length)];

      prompt = '''
        Generate 15 realistic bank transactions for a user who is **$randomPersona**.
        Return ONLY a raw JSON list.
        Keys: "merchant", "amount" (float), "category" (rent, utilities, savings, healthcare, groceries, transportation, entertainment, other).
        Make the amounts and merchants match this specific persona.
        Make sure the "Other" category dosen't get too many transactions.
        Example: [{"merchant": "Whole Foods", "amount": 45.20, "category": "groceries"}]
      ''';
    }

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      String? text = response.text;

      if (text == null) throw Exception("Empty response from AI");

      // --- ROBUST CLEANING (Prevents crashes) ---
      // Remove markdown
      text = text.replaceAll('```json', '').replaceAll('```', '').trim();
      
      // Find the start '[' and end ']' to ignore any "Here is your JSON" text
      int startIndex = text.indexOf('[');
      int endIndex = text.lastIndexOf(']');
      
      if (startIndex != -1 && endIndex != -1) {
        text = text.substring(startIndex, endIndex + 1);
      } else {
        throw Exception("AI did not return a valid list");
      }

      final List<dynamic> transactions = jsonDecode(text);

      int successCount = 0;
      for (var t in transactions) {
        try {
          await saveToDatabase(
            merchant: t['merchant'],
            amount: (t['amount'] as num).toDouble(),
            category: t['category'],
          );
          successCount++;
        } catch (e) {
          print("Skipped one: $e");
        }
      }
      return successCount;

    } catch (e) {
      print("Failed to generate history: $e");
      rethrow;
    }
  }
  
}