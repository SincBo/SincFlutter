import 'dart:convert';
import 'package:http/http.dart' as http;

class VPayService {
  final String baseUrl = "https://vpay.com.bo:7778/test/api";

  /// 1️⃣ Generate Token
  Future<String?> generateToken({
    required String user,
    required String password,
    required String companyId,
  }) async {
    final url = Uri.parse("$baseUrl/auth/login");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user": user,
        "password": password,
        "companyId": companyId,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["transactionIdentifier"];
    }

    print("Error token: ${response.body}");
    return null;
  }

  /// 2️⃣ Generate QR
  Future<Map<String, dynamic>?> generateQR({
    required String token,
    required double amount,
    required String expirationDate,
    required String transactionId,
  }) async {
    final url = Uri.parse("$baseUrl/transactions/doPayment");

    final headers = {
      "Content-Type": "application/json",
      "Authorization": token,
    };

    final body = {
      "operation": "VTO041",
      "header": [
        {"attribute": "currency", "value": "BOB"},
        {"attribute": "gloss", "value": "TEST - VPAY"},
        {"attribute": "amount", "value": amount.toString()},
        {"attribute": "expirationDate", "value": expirationDate},
        {"attribute": "additionalData", "value": "Dato adicional"},
        {"attribute": "destinationAccountId", "value": "3332CO"},
        {"attribute": "transactionIdentifier", "value": transactionId},
        {"attribute": "user", "value": "testVpay"},
        {"attribute": "company", "value": "1"},
        {"attribute": "originCollection", "value": "APP"},
        {"attribute": "callback", "value": "https://miweb.com/callback/vpay"},
      ],
      "detail": [
        {
          "items": [
            {"attribute": "YGN-RUTA1", "value": "2"},
          ]
        }
      ]
    };

    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      final resp = json["responseList"][0]["response"];

      return {
        "idQr": resp[0]["identificator"],
        "qrBase64": resp[1]["identificator"],
      };
    }

    print("Error generar QR: ${response.body}");
    return null;
  }
}
