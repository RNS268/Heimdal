import 'dart:convert';
import 'package:http/http.dart' as http;

class SettingsApiService {
  SettingsApiService({
    required this.baseUrl,
    required this.userId,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String userId;
  final http.Client _client;

  Map<String, String> get _headers => {
    "Content-Type": "application/json",
    "x-user-id": userId,
  };

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _client.get(
      Uri.parse("$baseUrl$path"),
      headers: _headers,
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      Uri.parse("$baseUrl$path"),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data["success"] != true) {
      throw Exception(data["error"] ?? "Settings API request failed");
    }
    return data;
  }
}
