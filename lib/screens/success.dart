import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gov_reg/models/parking_card.dart';
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
  Future<Uint8List?> _qrFuture = Future.value(null);

  // ✅ Typed model — set during didChangeDependencies
  ParkingCardRequestResponseDTO? _response;

  // ✅ Multi-result support (search may return a list)
  List<ParkingCardRequestResponseDTO> _allResults = [];
  int _currentIndex = 0;

  String selfiePath = "";
  Uint8List? selfieBytes;

  final GlobalKey _exportKey = GlobalKey();
  bool _saving = false;
  bool _showExportForCapture = false;

  bool _alive = true;
  bool _initedArgs = false;

  // ---------- CONVENIENCE GETTERS (from current response) ----------
  ParkingCardRequestResponseDTO get _current => _allResults.isNotEmpty
      ? _allResults[_currentIndex]
      : (_response ?? ParkingCardRequestResponseDTO());

  String get code => _current.code ?? "";
  String get token => _current.token ?? "";
  String get fullName => _current.name ?? "";
  String get phone => _current.phone ?? "";
  String get userType => _current.userType?.value ?? "";
  String get parkingRequestStatus => _current.parkingRequestStatus?.value ?? "";
  String get provinceCity => _current.provinceCity ?? "";
  int get requestDate => _current.requestDate ?? 0;
  String? get requestAtDate => _current.requestAtDate;

  // First vehicle helpers
  VehicleResponseDTO? get _firstVehicle =>
      (_current.vehicles != null && _current.vehicles!.isNotEmpty)
          ? _current.vehicles!.first
          : null;

  String get vehicleType => _firstVehicle?.vehicleType ?? "";

  // ---------- DISPLAY RULES ----------
  bool get showPoliceId =>
      userType == "INSIDE_OFFICER" || userType == "OUTSIDE_OFFICER";

  bool get showProvince =>
      userType == "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER";

  bool get showWorkInfo =>
      userType != "SECRETARY" && userType != "DEPUTY_SECRETARY";

  @override
  void dispose() {
    _alive = false;
    super.dispose();
  }

  // ---------- SAFE STRING ----------
  String _safe(dynamic v, {String fallback = "-"}) {
    final s = (v ?? "").toString().trim();
    if (s.isEmpty || s.toLowerCase() == "null") return fallback;
    return s;
  }

  // ---------- KHMER DATE ----------
  String _formatKhmerDate(DateTime d) {
    const khMonths = [
      "មករា",
      "កុម្ភៈ",
      "មីនា",
      "មេសា",
      "ឧសភា",
      "មិថុនា",
      "កក្កដា",
      "សីហា",
      "កញ្ញា",
      "តុលា",
      "វិច្ឆិកា",
      "ធ្នូ",
    ];

    String toKhmerNumber(String input) {
      const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
      const kh = ['០', '១', '២', '៣', '៤', '៥', '៦', '៧', '៨', '៩'];
      for (int i = 0; i < en.length; i++) {
        input = input.replaceAll(en[i], kh[i]);
      }
      return input;
    }

    return "${toKhmerNumber(d.day.toString())} ${khMonths[d.month - 1]} ${toKhmerNumber(d.year.toString())}";
  }

  String _formatYmdIntToKhmer(int yyyymmdd) {
    final s = yyyymmdd.toString().padLeft(8, '0');
    if (s.length != 8) return "-";
    return _formatKhmerDate(DateTime(
      int.parse(s.substring(0, 4)),
      int.parse(s.substring(4, 6)),
      int.parse(s.substring(6, 8)),
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initedArgs) return;
    _initedArgs = true;

    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};

    // ✅ Read typed model from args
    final response = args["response"];
    if (response is ParkingCardRequestResponseDTO) {
      _response = response;
    }

    // ✅ Read full list (search may pass multiple results)
    final allResults = args["allResults"];
    if (allResults is List<ParkingCardRequestResponseDTO> &&
        allResults.isNotEmpty) {
      _allResults = allResults;
      _currentIndex = 0;
    } else if (_response != null) {
      _allResults = [_response!];
      _currentIndex = 0;
    }

    // ✅ Selfie from args (submit path)
    selfieBytes = (args["selfieBytes"] is Uint8List)
        ? args["selfieBytes"] as Uint8List
        : null;
    selfiePath = (args["selfiePath"] ?? "").toString();

    precacheImage(const AssetImage("assets/img/about-moi-logo.png"), context);
    _qrFuture = _fetchQrPngOrNull();

    if (mounted) setState(() {});
  }

  // ✅ Switch to another result (search pager)
  void _switchToResult(int index) {
    if (index < 0 || index >= _allResults.length) return;
    setState(() {
      _currentIndex = index;
      _qrFuture = _fetchQrPngOrNull();
    });
  }

  Future<Uint8List?> _fetchQrPngOrNull() async {
    final t = token;
    if (t.isEmpty) return null;
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/api/v1/qr/parking/$t"),
        headers: {"Accept": "image/png"},
      );
      if (!_alive) return null;
      if (res.statusCode != 200) return null;
      return res.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  String _userTypeKhmer(String v) {
    switch (v) {
      case "GUEST":
        return "ភ្ញៀវ";
      case "INSIDE_OFFICER":
        return "មន្រ្តីបំរើការងារនៅក្នុងទីស្តីការក្រសួងមហាផ្ទៃ";
      case "OUTSIDE_OFFICER":
        return "មន្រ្តីបំរើការងារនៅក្រៅទីស្តីការក្រសួងមហាផ្ទៃ";
      case "SECRETARY":
        return "រដ្ឋលេខាធិការក្រសួងមហាផ្ទៃ";
      case "DEPUTY_SECRETARY":
        return "អនុរដ្ឋលេខាធិការ​ ក្រសួងមហាផ្ទៃ";
      case "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER":
        return "មន្ត្រីរដ្ឋបាលថ្នាក់ក្រោមជាតិ";
      default:
        return v;
    }
  }

  Future<Uint8List?> _captureExportPng() async {
    final ctx = _exportKey.currentContext;
    if (ctx == null) return null;
    final ro = ctx.findRenderObject();
    if (ro is! RenderRepaintBoundary) return null;

    for (int i = 0; i < 40; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!ro.debugNeedsPaint && ro.hasSize) break;
      await Future.delayed(const Duration(milliseconds: 25));
    }
    if (ro.debugNeedsPaint || !ro.hasSize) return null;

    final ui.Image image = await ro.toImage(pixelRatio: 3.5);
    final ByteData? bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd?.buffer.asUint8List();
  }

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

      setState(() => _showExportForCapture = true);
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 250));
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 250));
      await WidgetsBinding.instance.endOfFrame;

      final Uint8List? bytes = await _captureExportPng();
      if (mounted) setState(() => _showExportForCapture = false);

      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Capture failed ❌")),
        );
        return;
      }

      await PhotoManager.editor.saveImage(
        bytes,
        filename: "parking_badge_${DateTime.now().millisecondsSinceEpoch}.png",
        title: "Parking Badge",
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("រក្សាទុកចូល Photos ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted)
        setState(() {
          _saving = false;
          _showExportForCapture = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFDFB73B);

    // ---------- Date strings ----------
    String issueDateStr = "-";
    final rad = requestAtDate;
    if (rad != null && rad.isNotEmpty) {
      try {
        final parts = rad.split("-");
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            issueDateStr = _formatKhmerDate(DateTime(
                int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])));
          } else {
            issueDateStr = _formatKhmerDate(DateTime(
                int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0])));
          }
        }
      } catch (_) {}
    }
    final expiryDateStr =
        requestDate > 0 ? _formatYmdIntToKhmer(requestDate) : "-";

    // ---------- Build working-info map for badge ----------
    final cur = _current;
    final workingInfoMap = <String, dynamic>{
      "generalDepartment": _safe(cur.generalDepartment),
      "department": _safe(cur.department),
      "bureau": _safe(cur.bureau),
      "position": _safe(cur.position),
      "generalDepartmentText": _safe(cur.generalDepartmentText),
      "organization": _safe(cur.organization),
      "departmentText": _safe(cur.departmentText),
      "bureauText": _safe(cur.bureauText),
      "positionText": _safe(cur.positionText),
      "provinceCity": _safe(cur.provinceCity),
      "policeId": _safe(cur.policeId, fallback: ""),
    };

    // ✅ Convert typed VehicleResponseDTO list → List<Map> for badge widget
    final vehiclesMaps = (cur.vehicles ?? [])
        .map((v) => {
              "plateNumber": v.plateNumber ?? "",
              "brand": v.brand ?? "",
              "madeYear": (v.madeYear ?? 0).toString(),
              "plateSubCategory": v.plateSubCategory ?? "",
              "plateCode": v.plateCode ?? "",
              "vehicleType": v.vehicleType ?? "",
            })
        .toList();

    final badgeWidget = MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: _MoIStyleBadge(
        fullName: fullName,
        phone: phone,
        code: code,
        token: token,
        vehicleType: vehicleType,
        parkingRequestStatus: parkingRequestStatus,
        userTypeText: _userTypeKhmer(userType),
        vehicles: vehiclesMaps,
        workingInfo: workingInfoMap,
        selfieBytes: selfieBytes,
        selfiePath: selfiePath,
        qrFuture: _qrFuture,
        issueDateStr: issueDateStr,
        expiryDateStr: expiryDateStr,
        showPoliceId: showPoliceId,
        showWorkInfo: showWorkInfo,
        showProvince: showProvince,
        provinceCity: provinceCity,
      ),
    );

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ Pager row — shown only when search returned multiple results
                if (_allResults.length > 1) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _currentIndex > 0
                            ? () => _switchToResult(_currentIndex - 1)
                            : null,
                      ),
                      Text(
                        "${_currentIndex + 1} / ${_allResults.length}",
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _currentIndex < _allResults.length - 1
                            ? () => _switchToResult(_currentIndex + 1)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFFFCA28)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                        child: const Text("ត្រឡប់ក្រោយ",
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFDFB73B))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFCA28),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _saving ? null : _saveToPhotos,
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Icon(Icons.download_rounded,
                                        size: 18, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text("ទាញទុក",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white)),
                                  ]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFCA28),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _saving
                            ? null
                            : () =>
                                Navigator.pushNamed(context, Approute.welcome),
                        child: const Text("ទៅទំព័រដើម",
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      width: constraints.maxWidth,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: FittedBox(
                            fit: BoxFit.fitHeight,
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: _MoIStyleBadge.badgeW,
                              height: _MoIStyleBadge.badgeH,
                              child: badgeWidget,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Hidden off-screen widget used for high-res PNG capture
              if (_showExportForCapture)
                Positioned(
                  left: -4000,
                  top: 0,
                  child: IgnorePointer(
                    ignoring: true,
                    child: Opacity(
                      opacity: 0.01,
                      child: SizedBox(
                        width: _MoIStyleBadge.badgeW,
                        height: _MoIStyleBadge.badgeH,
                        child: RepaintBoundary(
                          key: _exportKey,
                          child: MediaQuery(
                            data: MediaQuery.of(context)
                                .copyWith(textScaler: TextScaler.noScaling),
                            child: _MoIStyleBadge(
                              fullName: fullName,
                              phone: phone,
                              code: code,
                              token: token,
                              vehicleType: vehicleType,
                              parkingRequestStatus: parkingRequestStatus,
                              userTypeText: _userTypeKhmer(userType),
                              vehicles: vehiclesMaps,
                              workingInfo: workingInfoMap,
                              selfieBytes: selfieBytes,
                              selfiePath: selfiePath,
                              qrFuture: _qrFuture,
                              issueDateStr: issueDateStr,
                              expiryDateStr: expiryDateStr,
                              showPoliceId: showPoliceId,
                              showWorkInfo: showWorkInfo,
                              showProvince: showProvince,
                              provinceCity: provinceCity,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ✅ Badge widget — unchanged visual, same parameters as before
// =============================================================================
class _MoIStyleBadge extends StatelessWidget {
  final String fullName;
  final String phone;
  final String code;
  final String token;
  final String userTypeText;
  final String parkingRequestStatus;
  final List vehicles; // List<Map<String,dynamic>> — built above
  final Map? workingInfo; // Map<String,dynamic>       — built above
  final Uint8List? selfieBytes;
  final String selfiePath;
  final Future<Uint8List?> qrFuture;
  final String issueDateStr;
  final String expiryDateStr;
  final String vehicleType;
  final bool showPoliceId;
  final bool showWorkInfo;
  final bool showProvince;
  final String provinceCity;

  const _MoIStyleBadge({
    required this.fullName,
    required this.phone,
    required this.code,
    required this.vehicleType,
    required this.token,
    required this.userTypeText,
    required this.parkingRequestStatus,
    required this.vehicles,
    required this.workingInfo,
    required this.selfieBytes,
    required this.selfiePath,
    required this.qrFuture,
    required this.issueDateStr,
    required this.expiryDateStr,
    required this.showPoliceId,
    required this.showWorkInfo,
    required this.showProvince,
    required this.provinceCity,
  });

  static const double badgeW = 1180;
  static const double badgeH = 1000;

  static const _navy = Color(0xFF0A2D66);
  static const _gold = Color(0xFFDFB73B);
  static const _line = Color(0xFFBBD4FF);
  static const _footerRed = Color(0xFFF04444);
  static const _cardBlue = Color(0xFF1E3A8A);

  String s(dynamic x) => (x ?? "").toString().trim();

  Map? _firstVehicle() {
    final list = vehicles.whereType<Map>().toList();
    return list.isEmpty ? null : list.first;
  }

  String vehicleTypeKh(String v) {
    switch (v) {
      case "CAR":
        return "រថយន្ត";
      case "MOTORBIKE":
        return "ម៉ូតូ";
      default:
        return v.isEmpty ? "-" : v;
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _firstVehicle();

    final plate = s(v?["plateNumber"]);
    final brand = s(v?["brand"]);
    final year = s(v?["madeYear"]);
    final subcategory = s(v?["plateSubCategory"]);
    final plateCode = s(v?["plateCode"]);

    final Map<String, dynamic> info =
        Map<String, dynamic>.from(workingInfo ?? {});

    String pick(List<String> keys, {String fallback = "-"}) {
      for (final k in keys) {
        final val = info[k];
        final ss = s(val);
        if (ss.isNotEmpty && ss.toLowerCase() != "null") return ss;
      }
      return fallback;
    }

    final ministry =
        pick(["generalDepartment", "generalDepartmentText", "organization"]);
    final dept = pick(["department", "departmentText"]);
    final office = pick(["bureau", "bureauText"]);
    final position = pick(["position", "positionText"]);
    final policeId = pick(["policeId"], fallback: "");
    final provCity = pick(["provinceCity", "province", "province_city"]);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: Container(
            width: badgeW,
            height: badgeH,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE6EEF9), width: 2),
            ),
            child: Stack(
              children: [
                // Background gradient
                Positioned.fill(
                    child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFFFFF), Color(0xFFF2F6FF)],
                    ),
                  ),
                )),

                // Watermark logo
                Positioned.fill(
                    child: Opacity(
                  opacity: 0.10,
                  child: Center(
                      child: Image.asset(
                    "assets/img/about-moi-logo.png",
                    width: 620,
                    height: 620,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  )),
                )),

                // Header row
                Positioned(
                  left: 36,
                  right: 36,
                  top: 26,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _gold, width: 3),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Image.asset("assets/img/about-moi-logo.png",
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high),
                      ),
                      const SizedBox(width: 18),
                      const Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("ក្រសួងមហាផ្ទៃ",
                                  style: TextStyle(
                                      color: _gold,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 36,
                                      height: 1.0)),
                              SizedBox(height: 6),
                              Text("MINISTRY OF INTERIOR",
                                  style: TextStyle(
                                      color: _gold,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 22,
                                      letterSpacing: 0.6,
                                      height: 1.0)),
                            ]),
                      ),
                      // QR code box
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border:
                                Border.all(color: Colors.black54, width: 2)),
                        padding: const EdgeInsets.all(6),
                        child: FutureBuilder<Uint8List?>(
                          future: qrFuture,
                          builder: (_, snap) {
                            if (!snap.hasData || snap.data == null) {
                              return const Center(
                                  child: Text("NO QR",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black54)));
                            }
                            return Image.memory(snap.data!,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Horizontal rule
                Positioned(
                    left: 36,
                    right: 36,
                    top: 170,
                    child: Container(height: 2, color: _line)),

                // Selfie photo box
                Positioned(
                  left: 46,
                  top: 210,
                  child: Container(
                    width: 300,
                    height: 320,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: _cardBlue, width: 5),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _badgePhoto(selfieBytes, selfiePath),
                    ),
                  ),
                ),

                // Plate number box
                Positioned(
                  left: 46,
                  top: 550,
                  child: Container(
                    width: 300,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _cardBlue, width: 3),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Column(children: [
                      const SizedBox(height: 12),
                      Text(subcategory.isEmpty ? "-" : subcategory,
                          style: const TextStyle(
                              color: _navy,
                              fontWeight: FontWeight.w900,
                              fontSize: 32,
                              height: 1.0)),
                      const SizedBox(height: 14),
                      Text(plate.isEmpty ? "-" : plate,
                          style: const TextStyle(
                              color: _navy,
                              fontWeight: FontWeight.w900,
                              fontSize: 40,
                              letterSpacing: 2,
                              height: 1.0)),
                      const Spacer(),
                      Container(
                        height: 46,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                            border: Border(
                                top: BorderSide(color: _cardBlue, width: 2))),
                        alignment: Alignment.center,
                        child: Text(
                          plateCode.isNotEmpty
                              ? plateCode
                              : (subcategory.isEmpty ? "-" : subcategory),
                          style: const TextStyle(
                              color: _footerRed,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              height: 1.0),
                        ),
                      ),
                    ]),
                  ),
                ),

                // Right panel — personal info + vehicle info
                Positioned(
                  left: 380,
                  right: 46,
                  top: 210,
                  bottom: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Personal info header with code
                      Container(
                        height: 62,
                        color: _navy,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(children: [
                          const Expanded(
                              child: Text("ព័ត៌មានផ្ទាល់ខ្លួន",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24))),
                          Text(code.isEmpty ? "GDDTM###########" : code,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                  letterSpacing: 0.6)),
                        ]),
                      ),
                      const SizedBox(height: 18),

                      _twoColRowSafe(
                          leftLabel: "នាមត្រកូល និងនាមខ្លួន",
                          leftValue: fullName,
                          rightLabel: "ប្រភេទមន្ត្រី",
                          rightValue: userTypeText),
                      const SizedBox(height: 14),

                      if (showPoliceId) ...[
                        _twoColRowSafe(
                            leftLabel: "អត្តលេខ",
                            leftValue: policeId,
                            rightLabel: "",
                            rightValue: ""),
                        const SizedBox(height: 14),
                      ],
                      if (showProvince) ...[
                        _twoColRowSafe(
                            leftLabel: "ខេត្ត/រាជធានី",
                            leftValue: provCity,
                            rightLabel: "",
                            rightValue: ""),
                        const SizedBox(height: 14),
                      ],
                      if (showWorkInfo) ...[
                        _twoColRowSafe(
                            leftLabel: "ក្រសួង/ស្ថាប័ន",
                            leftValue: ministry,
                            rightLabel: "នាយកដ្ឋាន/អង្គភាព",
                            rightValue: dept),
                        const SizedBox(height: 14),
                        _twoColRowSafe(
                            leftLabel: "ការិយាល័យ",
                            leftValue: office,
                            rightLabel: "តួនាទី",
                            rightValue: position),
                        const SizedBox(height: 14),
                      ],

                      _blueSectionTitle(
                          "ព័ត៌មាន ${vehicleTypeKh(vehicleType)}"),
                      const SizedBox(height: 12),

                      _twoColRowSafe(
                          leftLabel: "ស្លាកលេខ",
                          leftValue: plate,
                          rightLabel: "ម៉ាក",
                          rightValue: brand),
                      const SizedBox(height: 14),
                      _twoColRowSafe(
                          leftLabel: "ឆ្នាំផលិត",
                          leftValue: year,
                          rightLabel: "លេខទូរស័ព្ទ",
                          rightValue: phone),
                      const SizedBox(height: 18),

                      Row(children: const [
                        Text("សុពលភាពពី ",
                            style: TextStyle(
                                color: Color(0xFF8A94A6),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                height: 1.0)),
                        Spacer(),
                        Text("សុពលភាពដល់ ",
                            style: TextStyle(
                                color: Color(0xFF8A94A6),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                height: 1.0)),
                      ]),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("ថ្ងៃទី $issueDateStr",
                                style: const TextStyle(
                                    color: _footerRed,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                    height: 1.0)),
                            Text("ថ្ងៃទី $expiryDateStr",
                                style: const TextStyle(
                                    color: _navy,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                    height: 1.0)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Status footer
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _parkingStatusFooter(parkingRequestStatus),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _blueSectionTitle(String title) {
    return Container(
      height: 58,
      color: _navy,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
    );
  }

  static Widget _twoColRowSafe({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
  }) {
    Widget cell(
        {required String label,
        required String value,
        required CrossAxisAlignment align,
        required TextAlign textAlign}) {
      return Expanded(
        child: Column(crossAxisAlignment: align, children: [
          Text(label,
              textAlign: textAlign,
              style: const TextStyle(
                  color: Color(0xFF8A94A6),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  height: 1.0)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            alignment: align == CrossAxisAlignment.end
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: align == CrossAxisAlignment.end
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AutoSizeText(
                  value.trim().isEmpty ? "-" : value.trim(),
                  maxLines: 1,
                  minFontSize: 24,
                  stepGranularity: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textAlign: textAlign,
                  style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      height: 1.08),
                ),
              ),
            ),
          ),
        ]),
      );
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      cell(
          label: leftLabel,
          value: leftValue,
          align: CrossAxisAlignment.start,
          textAlign: TextAlign.left),
      const SizedBox(width: 32),
      cell(
          label: rightLabel,
          value: rightValue,
          align: CrossAxisAlignment.end,
          textAlign: TextAlign.right),
    ]);
  }

  static Widget _parkingStatusFooter(String? rawStatus) {
    final status = (rawStatus ?? "").trim().toLowerCase();
    Color bg;
    String label;

    if (status == "new" || status.isEmpty) {
      bg = Colors.blueGrey;
      label = "សំណើរកំពុងដាក់ស្នើរ";
    } else if (status == "pending") {
      bg = Colors.orange;
      label = "កំពុងរង់ចាំពិនិត្យ";
    } else if (status == "approve" || status == "approved") {
      bg = Colors.blue;
      label = "បានអនុម័ត";
    } else if (status == "active") {
      bg = Colors.green;
      label = "កំពុងប្រើប្រាស់";
    } else if (status == "reject" || status == "rejected") {
      bg = Colors.red;
      label = "បានបដិសេធ";
    } else {
      bg = Colors.blueGrey;
      label = "សំណើរកំពុងដាក់ស្នើរ";
    }

    return Container(
      height: 90,
      color: bg,
      alignment: Alignment.center,
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 34,
              letterSpacing: 0.6)),
    );
  }

  static Widget _badgePhoto(Uint8List? bytes, String path) {
    Widget fallback() => const Center(
        child: Icon(Icons.person, size: 80, color: Color(0xFF9AA6B2)));

    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(bytes,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => fallback());
    }
    if (path.isNotEmpty && File(path).existsSync()) {
      return Image.file(File(path),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => fallback());
    }
    return fallback();
  }
}
