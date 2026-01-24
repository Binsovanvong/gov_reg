import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RegisterSuccessScreen extends StatelessWidget {
  const RegisterSuccessScreen({
    super.key,
    required this.code,
    required this.token,
  });

  final String code;
  final String token;

  // Android emulator: 10.0.2.2
  // iOS simulator: 127.0.0.1
  static const String baseUrl = "http://10.0.2.2:8080";

  Future<Uint8List> _fetchQrPng() async {
    final uri = Uri.parse("$baseUrl/api/v1/qr/parking/$token");

    final res = await http.get(uri, headers: {"Accept": "image/png"});

    if (res.statusCode != 200) {
      throw Exception("QR HTTP ${res.statusCode}: ${res.body}");
    }
    return res.bodyBytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE2B10B),
      body: SafeArea(
        child: Center(
          child: Container(
            width: 360,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 18,
                  offset: Offset(0, 8),
                  color: Colors.black26,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00B36B),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      "អ្នកបានដាក់ស្នើជោគជ័យ",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Text(
                  code,
                  style: const TextStyle(
                    color: Color(0xFFB8860B),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 12),

                FutureBuilder<Uint8List>(
                  future: _fetchQrPng(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          "Failed to load QR: ${snapshot.error}",
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFB8860B),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.memory(
                        snapshot.data!,
                        width: 240,
                        height: 240,
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("ត្រឡប់ទៅក្រោយ"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE2B10B),
                          ),
                          onPressed: () {
                            // optional: implement save/share later
                          },
                          child: const Text("ទាញយក QRcode"),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
