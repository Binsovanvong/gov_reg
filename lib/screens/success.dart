import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gov_reg/routes/approute.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';

class RegisterSuccessMixedScreen extends StatefulWidget {
  const RegisterSuccessMixedScreen({super.key});

  @override
  State<RegisterSuccessMixedScreen> createState() =>
      _RegisterSuccessMixedScreenState();
}

class _RegisterSuccessMixedScreenState
    extends State<RegisterSuccessMixedScreen> {
  static const String baseUrl = "http://10.0.2.2:8080";

  late Future<Uint8List?> _qrFuture;

  late String code;
  late String token;

  late String fullName;
  late String phone;
  late String userType;
  late String parkingRequestStatus;


  Map workingInfo = {};
  List vehicles = [];

  // ✅ selfie
  String selfiePath = "";
  Uint8List? selfieBytes;

  // ✅ capture key (screen UI card - optional)
  final GlobalKey _captureKey = GlobalKey();

  // ✅ export key (badge card for download)
  final GlobalKey _exportKey = GlobalKey();

  bool _saving = false;

  // ✅ show export widget invisibly (painted) only during capture
  bool _showExportForCapture = false;

  // ✅ Hide "ព័ត៌មានការងារ" for these user types
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
    parkingRequestStatus = (args["parkingRequestStatus"] ?? "").toString();

    workingInfo =
        (args["workingInfo"] is Map) ? (args["workingInfo"] as Map) : {};
    vehicles = (args["vehicles"] is List) ? (args["vehicles"] as List) : [];

    selfiePath = (args["selfiePath"] ?? "").toString();
    if (selfiePath.isEmpty && vehicles.isNotEmpty && vehicles.first is Map) {
      selfiePath = ((vehicles.first as Map)["selfiePath"] ?? "").toString();
    }

    selfieBytes = (args["selfieBytes"] is Uint8List)
        ? args["selfieBytes"] as Uint8List
        : null;

    // ✅ preload logo (avoid blank on capture)
    precacheImage(const AssetImage("assets/img/about-moi-logo.png"), context);

    _qrFuture = _fetchQrPngOrNull();
  }
  Color getStatusColor(String status) {
  switch (status) {
    case "NEW":
      return Colors.blue;
    case "ASSIGNED":
      return Colors.orange;
    case "ACTIVE":
      return Colors.green;
    case "IN_PROGRESS":
      return Colors.lightBlue;
    case "RESOLVED":
      return Colors.teal;
    case "APPROVED":
      return Colors.greenAccent;
    case "CLOSED":
      return Colors.grey;
    case "REJECTED":
      return Colors.red;
    case "WAITING_INFO":
      return Colors.amber;
    default:
      return Colors.black;
  }
}

String getStatusText(String status) {
  switch (status) {
    case "NEW":
      return "សំណេីរថ្មី"; // New
    case "ASSIGNED":
      return "បានចាត់ចែង"; // Assigned
    case "ACTIVE":
      return "សកម្ម"; // Active
    case "IN_PROGRESS":
      return "កំពុងដំណើរការ"; // In Progress
    case "RESOLVED":
      return "បានដោះស្រាយ"; // Resolved
    case "APPROVED":
      return "អនុញ្ញាតអោយចូល"; // Approved
    case "CLOSED":
      return "បិទ"; // Closed
    case "REJECTED":
      return "មិនអនុញ្ញាតអោយចូល"; // Rejected
    case "WAITING_INFO":
      return "រង់ចាំព័ត៌មាន"; // Waiting Info
    default:
      return status; // fallback
  }
  }

  Future<Uint8List?> _fetchQrPngOrNull() async {
    if (token.isEmpty) return null;
    final uri = Uri.parse("$baseUrl/api/v1/qr/parking/$token");
    final res = await http.get(uri, headers: {"Accept": "image/png"});
    if (res.statusCode != 200) return null;
    return res.bodyBytes;
  }

  // ✅ Capture export badge as PNG bytes (FIXED: wait + must paint)
  Future<Uint8List?> _captureExportPng() async {
    final ctx = _exportKey.currentContext;
    if (ctx == null) return null;

    final boundary = ctx.findRenderObject() as RenderRepaintBoundary;

    // ✅ wait until painted (up to 20 frames)
    for (int i = 0; i < 20; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!boundary.debugNeedsPaint) break;
      await Future.delayed(const Duration(milliseconds: 30));
    }

    if (boundary.debugNeedsPaint) return null;

    final ui.Image image = await boundary.toImage(pixelRatio: 3.5);
    final ByteData? bd = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bd == null) return null;

    return bd.buffer.asUint8List();
  }

  // ✅ Save badge into Photos/Gallery (FIXED: Stack clip none + Opacity 0.01)
  Future<void> _saveToPhotos() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Save to Photos supports only Android/iOS")),
        );
        return;
      }

      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("សូមអនុញ្ញាត Photos permission")),
        );
        return;
      }

      // ✅ show export widget so it gets PAINTED
      setState(() => _showExportForCapture = true);

      // ✅ give time for layout + FutureBuilder + decode
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 150));
      await WidgetsBinding.instance.endOfFrame;

      final Uint8List? bytes = await _captureExportPng();

      // ✅ hide it again
      if (mounted) setState(() => _showExportForCapture = false);

      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Capture failed (not painted) ❌")),
        );
        return;
      }

      final filename =
          "parking_badge_${DateTime.now().millisecondsSinceEpoch}.png";

      await PhotoManager.editor.saveImage(
        bytes,
        filename: filename,
        title: "Parking Badge",
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("រក្សាទុកចូល Photos ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      // ✅ ALWAYS reset flags
      if (mounted) {
        setState(() {
          _saving = false;
          _showExportForCapture = false;
        });
      }
    }
  }

  // ✅ Show userType in Khmer
  String _userTypeKhmer(String v) {
    switch (v) {
      case "GUEST":
        return "ភ្ញៀវ";
      case "INSIDE_OFFICER":
        return "មន្រ្តីបំរើការងារនៅក្នុងទីស្តីការក្រសួងមហាឫ្ទៃ";
      case "OUTSIDE_OFFICER":
        return "មន្រ្តីបំរើការងារនៅក្រៅទីស្តីការក្រសួងមហាឫ្ទៃ";
      case "SECRETARY":
        return "រដ្ឋលេខាធិការក្រសួងមហាឫ្ទៃ";
      case "DEPUTY_SECRETARY":
        return "អនុរដ្ឋលេខាធិការ​ ក្រសួងមហាឫ្ទៃ";
      case "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER":
        return "មន្ត្រីរដ្ឋបាលថ្នាក់ក្រោមជាតិ";
      default:
        return v;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.none, // ✅ IMPORTANT (do not clip offscreen export)
          children: [
            // ✅ SCREEN UI
            _mainUi(context),

            // ✅ Export widget (painted but invisible)
            if (_showExportForCapture)
              Positioned(
                left: -2000, // off-screen
                top: 0,
                child: IgnorePointer(
                  ignoring: true,
                  child: Opacity(
                    opacity: 0.01, // ✅ NOT 0.0 (must paint!)
                    child: SizedBox(
                      width: 600,
                      height: 980,
                      child: RepaintBoundary(
                        key: _exportKey,
                        child: _ExportParkingBadge(
                          fullName: fullName,
                          phone: phone,
                          code: code,
                          parkingRequestStatus: parkingRequestStatus,
                          userTypeText: _userTypeKhmer(userType),
                          vehicles: vehicles, // ✅ supports 2 vehicles
                          selfieBytes: selfieBytes,
                          selfiePath: selfiePath,
                          qrFuture: _qrFuture,
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

  /// ============================
  /// ✅ Your original screen UI
  /// ============================
  Widget _mainUi(BuildContext context) {
    const navy = Color(0xFF0A2D66);
    const green = Color(0xFF00B26A);
    const gold = Color(0xFFDFB73B);

    return Column(
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
                      "ក្រសួងមហាឫ្ទៃ",
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
                child: RepaintBoundary(
                  key: _captureKey,
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
                        decoration: BoxDecoration(
                          color: getStatusColor(parkingRequestStatus),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                          ),
                        ),
                        child: Text(
                          getStatusText(parkingRequestStatus),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                        const SizedBox(height: 16),

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
                            _userTypeKhmer(userType),
                            textAlign: TextAlign.center,
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
                                  _row(
                                      "លេខកូដស្នើរ", code.isEmpty ? "-" : code),
                                  _row("លេខទូរស័ព្ទ",
                                      phone.isEmpty ? "-" : phone),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (!hideWorkInfo) ...[
                                _infoCard(
                                  title: "ព័ត៌មានការងារ",
                                  rows: [
                                    if ((workingInfo["policeId"] ?? "")
                                        .toString()
                                        .isNotEmpty)
                                      _row("អត្តលេខ",
                                          workingInfo["policeId"].toString()),
                                    if (_safe(workingInfo[
                                            "generalDepartmentText"])
                                        .isNotEmpty)
                                      _row(
                                          "ក្រសួង/ស្ថាប័ន",
                                          _safe(workingInfo[
                                              "generalDepartmentText"])),
                                    if (_safe(workingInfo["departmentText"])
                                        .isNotEmpty)
                                      _row("នាយកដ្ឋាន/អង្គភាព",
                                          _safe(workingInfo["departmentText"])),
                                    if (_safe(workingInfo["burauText"])
                                        .isNotEmpty)
                                      _row("ការិយាល័យ",
                                          _safe(workingInfo["burauText"])),
                                    if (_safe(workingInfo["positionText"])
                                        .isNotEmpty)
                                      _row("តួនាទី",
                                          _safe(workingInfo["positionText"])),
                                    if (_safe(workingInfo["provinceCity"])
                                        .isNotEmpty)
                                      _row("ខេត្ត/រាជធានី",
                                          _safe(workingInfo["provinceCity"])),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                              _vehicleCard(
                                  title: "ព័ត៌មានរថយន្ត", vehicles: vehicles),
                              const SizedBox(height: 12),
                              FutureBuilder<Uint8List?>(
                                future: _qrFuture,
                                builder: (context, snap) {
                                  if (snap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox(
                                      height: 90,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  if (!snap.hasData || snap.data == null) {
                                    return _hintBox(
                                        "មិនមាន QR Code (Guest submit ឬ token ទទេ)");
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
                                          border: Border.all(
                                            color: Color(0xFFF0D9A2),
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        side: const BorderSide(color: gold),
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text(
                                        "ត្រឡប់ក្រោយ",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: gold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // ✅ download
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: gold,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: _saving ? null : _saveToPhotos,
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 220),
                                        child: _saving
                                            ? const SizedBox(
                                                key: ValueKey("loading"),
                                                height: 18,
                                                width: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Row(
                                                key: ValueKey("text"),
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.download_rounded,
                                                      size: 18,
                                                      color: Colors.white),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    "ទាញទុក",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: gold,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: () => Navigator.pushNamed(
                                        context,
                                        Approute.welcome,
                                      ),
                                      child: const Text(
                                        "ទៅទំព័រដើម",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
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
        ),
      ],
    );
  }

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
  Widget _row(String label, String value) =>
      _InfoRow(label: label, value: value);

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
                  _InfoRow(
                      label: "រថយន្ត #${i + 1}",
                      value: type.isEmpty ? "-" : type),
                  _InfoRow(label: "ម៉ាក", value: brand.isEmpty ? "-" : brand),
                  _InfoRow(
                      label: "ស្លាកលេខ", value: plate.isEmpty ? "-" : plate),
                  _InfoRow(label: "ពណ៌", value: color.isEmpty ? "-" : color),
                  _InfoRow(
                      label: "ឆ្នាំផលិត", value: year.isEmpty ? "-" : year),
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

/// =========================
/// ✅ Export Badge Card
/// =========================
class _ExportParkingBadge extends StatelessWidget {
  final String fullName;
  final String phone;
  final String code;
  final String userTypeText;
  final String parkingRequestStatus;
  final List vehicles;
  final Uint8List? selfieBytes;
  final String selfiePath;
  final Future<Uint8List?> qrFuture;

  const _ExportParkingBadge({
    required this.fullName,
    required this.phone,
    required this.code,
    required this.userTypeText,
    required this.vehicles,
    required this.selfieBytes,
    required this.selfiePath,
    required this.qrFuture,
    required this.parkingRequestStatus,
  });

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0A2D66);
    const gold = Color(0xFFDFB73B);
    const light = Color(0xFFF8FAFC);
    const border = Color(0xFFE2E8F0);

    String s(dynamic x) => (x ?? "").toString().trim();

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              const Text(" : ", style: TextStyle(fontSize: 10)),
              Expanded(
                child: Text(
                  value.isEmpty ? "-" : value,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        );

    Widget vehicleBox(int idx, Map v) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: light,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Vehicle #${idx + 1}",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: navy,
              ),
            ),
            const SizedBox(height: 6),
            row("Type", s(v["vehicleType"])),
            row("Brand", s(v["brand"])),
            row("Plate", s(v["plateNumber"])),
            row("Color", s(v["color"])),
            row("Year", s(v["madeYear"])),
          ],
        ),
      );
    }

    final List<Map> top2Vehicles =
        vehicles.whereType<Map>().take(2).map((e) => e).toList();

    return Material(
      color: Colors.white,
      child: Center(
        child: Container(
          width: 600,
          height: 980,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: gold, width: 3),
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: gold,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Image.asset(
                        "assets/img/about-moi-logo.png",
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ក្រសួងមហាឫ្ទៃ",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "MINISTRY OF INTERIOR",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        "PARKING PASS",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _badgePhoto(selfieBytes, selfiePath),
              const SizedBox(height: 10),
              Text(
                fullName.isEmpty ? "-" : fullName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userTypeText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: light,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    row("Code", code),
                    row("Phone", phone),
                  ],
                ),
              ),
              if (top2Vehicles.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: light,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: const Text(
                    "No vehicle information",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                for (int i = 0; i < top2Vehicles.length; i++)
                  vehicleBox(i, top2Vehicles[i]),
              ],
              const Spacer(),
              FutureBuilder<Uint8List?>(
                future: qrFuture,
                builder: (context, snap) {
                  final bytes = snap.data;

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: gold),
                        ),
                        child: bytes == null
                            ? const SizedBox(
                                width: 140,
                                height: 140,
                                child: Center(
                                  child: Text(
                                    "No QR",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              )
                            : Image.memory(
                                bytes,
                                width: 200,
                                height: 200,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Scan to Verify",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgePhoto(Uint8List? bytes, String path) {
    Widget fallback() => const Center(
          child: Icon(Icons.person, size: 55, color: Color(0xFF94A3B8)),
        );

    if (bytes != null && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.memory(
          bytes,
          width: 140,
          height: 180,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      );
    }

    final canRead = path.isNotEmpty && File(path).existsSync();

    return Container(
      width: 140,
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: canRead ? Image.file(File(path), fit: BoxFit.cover) : fallback(),
    );
  }
}
