import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class TelegramService {
  static Future<String?> getBotToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyBotToken);
  }

  static Future<String?> getChatId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyChatId);
  }

  static Future<void> saveCredentials(String token, String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyBotToken, token.trim());
    await prefs.setString(AppConstants.keyChatId, chatId.trim());
  }

  /// Send a text message
  static Future<bool> sendMessage(String text) async {
    final token = await getBotToken();
    final chatId = await getChatId();
    if (token == null || chatId == null || token.isEmpty || chatId.isEmpty) {
      return false;
    }

    try {
      final url = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': text,
          'parse_mode': 'HTML',
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Send a document (backup file)
  static Future<bool> sendDocument({
    required List<int> bytes,
    required String filename,
    String? caption,
  }) async {
    final token = await getBotToken();
    final chatId = await getChatId();
    if (token == null || chatId == null || token.isEmpty || chatId.isEmpty) {
      return false;
    }

    try {
      final url = Uri.parse('https://api.telegram.org/bot$token/sendDocument');
      final request = http.MultipartRequest('POST', url);
      request.fields['chat_id'] = chatId;
      if (caption != null) request.fields['caption'] = caption;

      request.files.add(http.MultipartFile.fromBytes(
        'document',
        bytes,
        filename: filename,
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get latest document from the chat (for admin restore)
  /// Note: Telegram Bot API getUpdates is limited. For simplicity in v1
  /// we ask user to forward or manually import. Later can improve.
  static Future<List<Map<String, dynamic>>> getRecentUpdates({int limit = 10}) async {
    final token = await getBotToken();
    if (token == null || token.isEmpty) return [];

    try {
      final url = Uri.parse(
        'https://api.telegram.org/bot$token/getUpdates?limit=$limit&allowed_updates=["message"]',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['ok'] != true) return [];

      final results = data['result'] as List? ?? [];
      return results.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
