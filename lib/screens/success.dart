import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:gov_reg/routes/approute.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class RegisterSuccessScreen extends StatefulWidget {
  const RegisterSuccessScreen({
    super.key,
    required this.code,
    required this.token,
  });

  final String code;
  final String token;

  @override
  State<RegisterSuccessScreen> createState() => _RegisterSuccessScreenState();
}

class _RegisterSuccessScreenState extends State<RegisterSuccessScreen> {
  // Android emulator: 10.0.2.2
  // iOS simulator: 127.0.0.1
  static const String baseUrl = "http://10.0.2.2:8080";

  late Future<Uint8List> _qrFuture;

  // ✅ capture key ONLY for downloaded image
  final GlobalKey _downloadKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _qrFuture = _fetchQrPng();
  }

  Future<Uint8List> _fetchQrPng() async {
    final uri = Uri.parse("$baseUrl/api/v1/qr/parking/${widget.token}");
    final res = await http.get(uri, headers: {"Accept": "image/png"});
    if (res.statusCode != 200) {
      throw Exception("QR HTTP ${res.statusCode}: ${res.body}");
    }
    return res.bodyBytes;
  }

  /// ✅ Works on Android + iOS
  Future<bool> _requestSavePermission() async {
    // iOS: best permission to only add to Photos (no read)
    final addOnly = await Permission.photosAddOnly.request();
    if (addOnly.isGranted) return true;

    // iOS/Android: full photos access
    final photos = await Permission.photos.request();
    if (photos.isGranted) return true;

    // Android (old devices): storage
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  Future<void> _downloadCleanQrImage(BuildContext context) async {
    try {
      final ok = await _requestSavePermission();
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permission denied")),
        );
        return;
      }

      // ensure hidden widget painted
      await Future.delayed(const Duration(milliseconds: 120));

      final boundary = _downloadKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("Download widget not ready");

      final ui.Image image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("PNG create failed");

      final pngBytes = byteData.buffer.asUint8List();

      // save to temp file then gallery/photos
      final tempDir = await getTemporaryDirectory();
      final file = File(
        "${tempDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png",
      );
      await file.writeAsBytes(pngBytes);

      // ✅ works on Android + iOS
      await Gal.putImage(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Save failed: $e")),
      );
    }
  }

  // ✅ Clean design image (saved file looks like this)
  Widget _downloadDesign(Uint8List qrBytes) {
    const gold = Color(0xFFE2B10B);

    return RepaintBoundary(
      key: _downloadKey,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // logo circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: gold, width: 2),
              ),
              child: ClipOval(
                child: Image.asset(
                  "assets/img/about-moi-logo.png",
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) =>
                      const Icon(Icons.account_balance, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 14),

            Text(
              widget.code,
              style: const TextStyle(
                color: gold,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: gold, width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.memory(
                qrBytes,
                width: 300,
                height: 300,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ UI for screen (first image)
  Widget _screenDesign(Uint8List qrBytes) {
    const green = Colors.green;
    const orange = Color(0xFFF2A100);
    const gold = Color(0xFFE2B10B);

    return Stack(
      children: [
        Container(height: 180, color: gold),
        Center(
          child: Container(
            width: 360,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 14,
                  offset: Offset(0, 6),
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
                    color: green,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      "សូមទាញយកQRCODEរបស់អ្នកដើម្បីផ្ទៀងផ្ទាត់",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: gold, width: 2),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      "assets/img/about-moi-logo.png",
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) =>
                          const Icon(Icons.account_balance, size: 40),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  widget.code,
                  style: const TextStyle(
                    color: gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: gold, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.memory(
                    qrBytes,
                    width: 240,
                    height: 240,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 18),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontSize: 14),
                          ),
                          onPressed: () => Navigator.pushNamed(context, Approute.welcome),
                          child: const Text("ត្រឡប់ទៅទំព័រដើម"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: orange,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontSize: 14),
                          ),
                          onPressed: () => _downloadCleanQrImage(context),
                          child: const Text("ទាញយក QRនេះ"),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: FutureBuilder<Uint8List>(
          future: _qrFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "Failed to load QR: ${snapshot.error}",
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final qrBytes = snapshot.data!;

            return Stack(
              children: [
                // ✅ what user sees
                _screenDesign(qrBytes),

                // ✅ hidden widget (ONLY for saving)
                Positioned(
                  left: -5000,
                  top: 0,
                  child: Opacity(
                    opacity: 0.01,
                    child: _downloadDesign(qrBytes),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
