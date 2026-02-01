import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gov_reg/routes/approute.dart';
import 'package:http/http.dart' as http;

class RegisterSuccessMixedScreen extends StatefulWidget {
  const RegisterSuccessMixedScreen({super.key});

  @override
  State<RegisterSuccessMixedScreen> createState() =>
      _RegisterSuccessMixedScreenState();
}

class _RegisterSuccessMixedScreenState extends State<RegisterSuccessMixedScreen> {
  static const String baseUrl = "http://10.0.2.2:8080";

  late Future<Uint8List?> _qrFuture;

  late String code;
  late String token;

  late String fullName;
  late String phone;
  late String userType;

  Map workingInfo = {};
  List vehicles = [];

  // ✅ selfie
  String selfiePath = "";
  Uint8List? selfieBytes;

  bool get hideWorkInfo =>
      userType == "SECRETARY" || userType == "DEPUTY_SECRETARY";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};

    code = (args["code"] ?? "").toString();
    token = (args["token"] ?? "").toString();

    fullName = (args["fullName"] ?? "").toString();
    phone = (args["phone"] ?? "").toString();
    userType = (args["userType"] ?? "").toString();

    workingInfo = (args["workingInfo"] is Map) ? (args["workingInfo"] as Map) : {};
    vehicles = (args["vehicles"] is List) ? (args["vehicles"] as List) : [];

    selfiePath = (args["selfiePath"] ?? "").toString();
    selfieBytes = (args["selfieBytes"] is Uint8List) ? args["selfieBytes"] as Uint8List : null;

    _qrFuture = _fetchQrPngOrNull();
  }

  Future<Uint8List?> _fetchQrPngOrNull() async {
    if (token.isEmpty) return null;
    final uri = Uri.parse("$baseUrl/api/v1/qr/parking/$token");
    final res = await http.get(uri, headers: {"Accept": "image/png"});
    if (res.statusCode != 200) return null;
    return res.bodyBytes;
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0A2D66);
    const green = Color(0xFF00B26A);
    const gold = Color(0xFFDFB73B);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // header
            Container(
              color: gold,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Row(
                children: [
                  Container(
                    width: 75,
                    height: 75,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Image.asset(
                        "assets/img/about-moi-logo.png",
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ក្រសួងមហាផ្ទៃ",
                          style: TextStyle(
                            color: Color(0xFFF4F6FA),
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "MINISTRY OF INTERIOR",
                          style: TextStyle(
                            color: Color(0xFFF4F6FA),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // title bar
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: const BoxDecoration(
                              color: green,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(18),
                                topRight: Radius.circular(18),
                              ),
                            ),
                            child: const Text(
                              "បញ្ជូនសំណើរជោគជ័យ",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ✅ profile block with selfie
                          _profileBlock(),

                          const SizedBox(height: 10),
                          Text(
                            fullName.isEmpty ? "Profile" : fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: navy,
                            ),
                          ),
                          if (userType.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              userType,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7680),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                _infoCard(
                                  title: "ព័ត៌មានសំណើរ",
                                  rows: [
                                    _row("លេខកូដស្នើរ", code.isEmpty ? "-" : code),
                                    _row("លេខទូរស័ព្ទ", phone.isEmpty ? "-" : phone),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                if (!hideWorkInfo) ...[
                                  _infoCard(
                                    title: "ព័ត៌មានការងារ",
                                    rows: [
                                      if ((workingInfo["policeId"] ?? "").toString().isNotEmpty)
                                        _row("អត្តលេខ", workingInfo["policeId"].toString()),
                                      if (_safe(workingInfo["generalDepartmentText"]).isNotEmpty)
                                        _row("ក្រសួង/ស្ថាប័ន", _safe(workingInfo["generalDepartmentText"])),
                                      if (_safe(workingInfo["departmentText"]).isNotEmpty)
                                        _row("នាយកដ្ឋាន/អង្គភាព", _safe(workingInfo["departmentText"])),
                                      if (_safe(workingInfo["burauText"]).isNotEmpty)
                                        _row("ការិយាល័យ", _safe(workingInfo["burauText"])),
                                      if (_safe(workingInfo["positionText"]).isNotEmpty)
                                        _row("តួនាទី", _safe(workingInfo["positionText"])),
                                      if (_safe(workingInfo["provinceCity"]).isNotEmpty)
                                        _row("ខេត្ត/រាជធានី", _safe(workingInfo["provinceCity"])),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                _vehicleCard(title: "ព័ត៌មានរថយន្ត", vehicles: vehicles),
                                const SizedBox(height: 12),

                                FutureBuilder<Uint8List?>(
                                  future: _qrFuture,
                                  builder: (context, snap) {
                                    if (snap.connectionState == ConnectionState.waiting) {
                                      return const SizedBox(
                                        height: 90,
                                        child: Center(child: CircularProgressIndicator()),
                                      );
                                    }
                                    if (!snap.hasData || snap.data == null) {
                                      return _hintBox("មិនមាន QR Code (Guest submit ឬ token ទទេ)");
                                    }
                                    return Column(
                                      children: [
                                        const Text(
                                          "QR Code",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFFDD7B25),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: const Color(0xFFF0D9A2)),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Image.memory(
                                            snap.data!,
                                            width: 110,
                                            height: 110,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),

                                const SizedBox(height: 18),

                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          side: const BorderSide(color: gold),
                                        ),
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text(
                                          "ត្រឡប់ក្រោយ",
                                          style: TextStyle(fontWeight: FontWeight.w700, color: gold),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: gold,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                        onPressed: () => Navigator.pushNamed(context, Approute.welcome),
                                        child: const Text(
                                          "ទៅទំព័រដើម",
                                          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Selfie Profile Widget (BEST: memory -> fallback file)
  Widget _profileBlock() {
    Widget fallbackIcon() => const Center(
          child: Icon(Icons.person, size: 54, color: Color(0xFF9AA6B2)),
        );

    if (selfieBytes != null && selfieBytes!.isNotEmpty) {
      return Container(
        width: 110,
        height: 140,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3E7EC)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.memory(
          selfieBytes!,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => fallbackIcon(),
        ),
      );
    }

    final canReadFile = selfiePath.isNotEmpty && File(selfiePath).existsSync();

    return Container(
      width: 110,
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E7EC)),
      ),
      clipBehavior: Clip.antiAlias,
      child: canReadFile
          ? Image.file(
              File(selfiePath),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => fallbackIcon(),
            )
          : fallbackIcon(),
    );
  }

  String _safe(dynamic v) => (v ?? "").toString().trim();

  Widget _row(String label, String value) => _InfoRow(label: label, value: value);

  Widget _infoCard({required String title, required List<Widget> rows}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0D9A2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFFDD7B25),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }

  Widget _vehicleCard({required String title, required List vehicles}) {
    if (vehicles.isEmpty) return _hintBox("មិនមានព័ត៌មានរថយន្ត");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0D9A2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFFDD7B25),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(vehicles.length, (i) {
            final v = vehicles[i] as Map;
            final brand = (v["brand"] ?? "").toString();
            final plate = (v["plateNumber"] ?? "").toString();
            final color = (v["color"] ?? "").toString();
            final year = (v["madeYear"] ?? "").toString();
            final type = (v["vehicleType"] ?? "").toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6EDF5)),
              ),
              child: Column(
                children: [
                  _InfoRow(label: "រថយន្ត #${i + 1}", value: type.isEmpty ? "-" : type),
                  _InfoRow(label: "ម៉ាក", value: brand.isEmpty ? "-" : brand),
                  _InfoRow(label: "ស្លាកលេខ", value: plate.isEmpty ? "-" : plate),
                  _InfoRow(label: "ពណ៌", value: color.isEmpty ? "-" : color),
                  _InfoRow(label: "ឆ្នាំផលិត", value: year.isEmpty ? "-" : year),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _hintBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EDF5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF0A2D66)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF4A5560),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const Text(" : "),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
