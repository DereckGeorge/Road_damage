import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Use your computer's IP address instead of localhost for mobile development
  // You can find your IP address using 'ipconfig' on Windows or 'ifconfig' on Mac/Linux
  static const String baseUrl =
      'https://rmis.onrender.com'; // Your computer's IP address

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception(
          'Failed to login: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Login error: $e');
      throw Exception('Failed to login: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDamageClasses() async {
    final response = await http.get(
      Uri.parse('$baseUrl/damage-class'),
      headers: {'accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load damage classes');
  }

  Future<Map<String, dynamic>> uploadPhoto({
    required String userId,
    required String fullname,
    required String email,
    required String imageData,
    required Map<String, dynamic> location,
    required String roadName,
    required String damageClass,
    required String comment,
    required String surveyStartDate,
    required String surveyEndDate,
  }) async {
    final requestBody = {
      'userId': userId,
      'fullname': fullname,
      'email': email,
      'imageData': imageData,
      'location': location,
      'roadName': roadName,
      'damageClass': damageClass,
      'comment': comment,
      'localTime': DateTime.now().toLocal().toString(),
      'surveyStartDate': surveyStartDate,
      'surveyEndDate': surveyEndDate,
    };

    print('Submitting report with image data length: ${imageData.length}');
    print('Request body keys: ${requestBody.keys.toList()}');
    print('Location data: $location');

    final response = await http.post(
      Uri.parse('$baseUrl/upload-photo'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    print('Submit response status: ${response.statusCode}');
    print('Submit response body: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 403) {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['message'] ?? 'Permission denied');
    }

    throw Exception(
        'Failed to submit report: ${response.statusCode} - ${response.body}');
  }

  Future<Map<String, dynamic>> editPhoto({
    required String photoId,
    required String roadName,
    required String damageClass,
    required String comment,
    required String editReason,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/edit-photo/$photoId'),
      headers: {
        'Content-Type': 'application/json',
        'accept': '*/*',
      },
      body: jsonEncode({
        'roadName': roadName,
        'damageClass': damageClass,
        'comment': comment,
        'editReason': editReason,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['message'] ?? 'Failed to edit photo');
    }
  }

  Future<Map<String, dynamic>> getReports() async {
    final response = await http.get(
      Uri.parse('$baseUrl/get-all-photos'),
      headers: {'accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load reports');
  }

  Future<List<dynamic>> getAssignedRoads(String email) async {
    final response = await http.get(
      Uri.parse('$baseUrl/roads/surveyor/$email'),
      headers: {'accept': '*/*'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load assigned roads');
    }
  }

  Future<Map<String, dynamic>> getRejectedPhotos(String email) async {
    final response = await http.get(
      Uri.parse('$baseUrl/rejected-photos/$email'),
      headers: {'accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load rejected photos');
    }
  }
}
