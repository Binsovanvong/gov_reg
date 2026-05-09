import 'dart:io';
import 'dart:typed_data';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:gov_reg/api/api.dart';
import 'package:gov_reg/models/parking_card.dart';
import 'package:gov_reg/routes/approute.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';

class RegisterSuccessMixedScreen extends StatefulWidget {
  const RegisterSuccessMixedScreen({super.key});

  @override
  State<RegisterSuccessMixedScreen> createState() =>
      _RegisterSuccessMixedScreenState();
}

class _RegisterSuccessMixedScreenState
    extends State<RegisterSuccessMixedScreen> {
  static const String baseUrl = "https://ees.interior.gov.kh";

  final ScreenshotController _screenshotController = ScreenshotController();

  double _badgeScale = 0.92;

  Future<Uint8List?> _qrFuture = Future.value(null);
  Uint8List? _qrBytes;

  ParkingCardRequestResponseDTO? _response;
  List<ParkingCardRequestResponseDTO> _allResults = [];
  int _currentIndex = 0;

  String selfiePath = "";
  Uint8List? selfieBytes;

  bool _saving = false;
  bool _alive = true;
  bool _initedArgs = false;
  OverlayEntry? _topSnackBar;

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

  int get requestDate {
    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
    final response = args["response"];
    if (response is ParkingCardRequestResponseDTO &&
        response.requestDate != null &&
        response.requestDate! > 0) {
      return response.requestDate!;
    }
    return _current.requestDate ?? 0;
  }

  String? get requestAtDate {
    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
    final response = args["response"];
    if (response is ParkingCardRequestResponseDTO) {
      return response.requestAtDate;
    }
    return _current.requestAtDate;
  }

  VehicleResponseDTO? get _firstVehicle =>
      (_current.vehicles != null && _current.vehicles.isNotEmpty)
          ? _current.vehicles.first
          : null;

  String get vehicleType => _firstVehicle?.vehicleType ?? "";

  bool get showPoliceId =>
      userType == "INSIDE_OFFICER" || userType == "OUTSIDE_OFFICER";

  bool get showProvince =>
      userType == "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER";

  bool get showWorkInfo =>
      userType == "INSIDE_OFFICER" ||
      userType == "OUTSIDE_OFFICER" ||
      userType == "GUEST";

  @override
  void dispose() {
    _topSnackBar?.remove();
    _topSnackBar = null;
    _alive = false;
    super.dispose();
  }

  void _showTopSnackBar(String message, {bool isSuccess = true}) {
    _topSnackBar?.remove();
    _topSnackBar = null;

    _topSnackBar = OverlayEntry(
      builder: (context) => _TopSnackBarWidget(
        message: message,
        isSuccess: isSuccess,
        onDismiss: () {
          _topSnackBar?.remove();
          _topSnackBar = null;
        },
      ),
    );

    Overlay.of(context).insert(_topSnackBar!);
  }

  void _showCreativeSuccessTopSnackBar() {
    _showTopSnackBar("បានទាញទុករូបភាពដោយជោគជ័យ", isSuccess: true);
  }

  String _safe(dynamic v, {String fallback = "-"}) {
    final s = (v ?? "").toString().trim();
    if (s.isEmpty || s.toLowerCase() == "null") return fallback;
    return s;
  }

  Future<bool> _requestPhotoPermissions() async {
    try {
      if (Platform.isIOS) {
        var status = await Permission.photosAddOnly.status;
        if (status.isDenied || status.isRestricted) {
          status = await Permission.photosAddOnly.request();
        }

        if (status.isGranted || status.isLimited) {
          return true;
        }

        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
        return false;
      }

      if (Platform.isAndroid) {
        var photos = await Permission.photos.status;
        if (photos.isDenied) {
          photos = await Permission.photos.request();
        }
        if (photos.isGranted || photos.isLimited) {
          return true;
        }

        var storage = await Permission.storage.status;
        if (storage.isDenied) {
          storage = await Permission.storage.request();
        }
        if (storage.isGranted) {
          return true;
        }

        if (photos.isPermanentlyDenied || storage.isPermanentlyDenied) {
          await openAppSettings();
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("Permission error: $e");
      return false;
    }
  }

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

  Future<void> _loadSelfieFromAttachments() async {
    if (selfieBytes != null) return;
    if (_current.attachments.isEmpty) return;

    final selfieAttachment = _current.attachments.firstWhere(
      (a) => a.attachmentType == "INVITATION_DOCUMENT",
      orElse: () => AttachmentDTO(),
    );

    final id = selfieAttachment.id;
    if (id == null || id.isEmpty) return;

    final bytes = await Api.fetchAttachmentBytes(id);
    if (!mounted) return;

    if (bytes != null && bytes.isNotEmpty) {
      setState(() => selfieBytes = bytes);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initedArgs) return;
    _initedArgs = true;

    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};

    final response = args["response"];
    if (response is ParkingCardRequestResponseDTO) {
      _response = response;
    }

    final allResults = args["allResults"];
    if (allResults is List<ParkingCardRequestResponseDTO> &&
        allResults.isNotEmpty) {
      _allResults = allResults;
      _currentIndex = 0;
    } else if (_response != null) {
      _allResults = [_response!];
      _currentIndex = 0;
    }

    selfieBytes = (args["selfieBytes"] is Uint8List)
        ? args["selfieBytes"] as Uint8List
        : null;
    selfiePath = (args["selfiePath"] ?? "").toString();

    precacheImage(const AssetImage("assets/img/about-moi-logo.png"), context);

    _qrFuture = _fetchQrPngOrNull();
    _qrFuture.then((bytes) {
      if (!mounted) return;
      setState(() => _qrBytes = bytes);
    });

    _loadSelfieFromAttachments();

    if (mounted) setState(() {});

    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _badgeScale = 1.0);
    });
  }

  void _switchToResult(int index) {
    if (index < 0 || index >= _allResults.length) return;

    setState(() {
      _currentIndex = index;
      selfieBytes = null;
      _qrBytes = null;
      _qrFuture = _fetchQrPngOrNull();
    });

    _qrFuture.then((bytes) {
      if (!mounted) return;
      setState(() => _qrBytes = bytes);
    });

    _loadSelfieFromAttachments();
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

  Future<Uint8List?> _captureBadgePng() async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(
        Duration(milliseconds: Platform.isIOS ? 800 : 400),
      );

      return await _screenshotController.capture(
        delay: Duration(milliseconds: Platform.isIOS ? 300 : 150),
        pixelRatio: Platform.isIOS ? 2.0 : 2.5,
      );
    } catch (e, stack) {
      debugPrint("screenshot capture error: $e");
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  Future<void> _saveToPhotos() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final hasPermission = await _requestPhotoPermissions();

      if (!hasPermission) {
        _showTopSnackBar(
          "❌ Permission denied. Please allow Photos access in Settings.",
          isSuccess: false,
        );
        return;
      }

      await _loadSelfieFromAttachments();

      if (token.isNotEmpty && _qrBytes == null) {
        try {
          final bytes = await _qrFuture;
          if (mounted) {
            setState(() => _qrBytes = bytes);
          }
        } catch (_) {}
      }

      await Future.delayed(
        Duration(milliseconds: Platform.isIOS ? 700 : 400),
      );
      await WidgetsBinding.instance.endOfFrame;

      final bytes = await _captureBadgePng();

      if (bytes == null || bytes.isEmpty) {
        _showTopSnackBar("❌ Capture failed", isSuccess: false);
        return;
      }

      await Gal.putImageBytes(bytes);

      if (mounted) {
        setState(() => _badgeScale = 0.88);
      }

      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() => _badgeScale = 1.0);
      });

      _showCreativeSuccessTopSnackBar();
    } catch (e, stack) {
      debugPrint("SAVE ERROR: $e");
      debugPrintStack(stackTrace: stack);
      _showTopSnackBar("❌ Failed to save image", isSuccess: false);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _creativeDownloadButton({
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: onTap == null ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFE082),
                  Color(0xFFFFCA28),
                  Color(0xFFFFA000),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB300).withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.download_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "ទាញទុក",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontSize: 16,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _creativeHomeButton({
    required VoidCallback? onTap,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: onTap == null ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFDFB73B),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.home_rounded,
                    size: 21,
                    color: Color(0xFFDFB73B),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "ទំព័រដើម",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFDFB73B),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime parseStartDate(String? raw) {
      if (raw == null || raw.trim().isEmpty) {
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day);
      }

      try {
        final parts = raw.split("-");
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            return DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          }
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } catch (_) {}

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }

    final startDate = parseStartDate(requestAtDate);
    final issueDateStr = _formatKhmerDate(startDate);

    String expiryDateStr = "-";
    if (requestDate > 0) {
      final endDate = startDate.add(Duration(days: requestDate));
      expiryDateStr = _formatKhmerDate(endDate);
    }

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

    final vehiclesMaps = cur.vehicles
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
      child: Screenshot(
        controller: _screenshotController,
        child: _MoIStyleBadge(
          fullName: fullName,
          phone: phone,
          code: code,
          token: token,
          vehicleType: vehicleType,
          parkingRequestStatus: parkingRequestStatus,
          userTypeText: _userTypeKhmer(userType),
          rawUserType: userType,
          vehicles: vehiclesMaps,
          workingInfo: workingInfoMap,
          selfieBytes: selfieBytes,
          selfiePath: selfiePath,
          qrBytes: _qrBytes,
          issueDateStr: issueDateStr,
          expiryDateStr: expiryDateStr,
          showPoliceId: showPoliceId,
          showWorkInfo: showWorkInfo,
          showProvince: showProvince,
          provinceCity: provinceCity,
        ),
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
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _currentIndex < _allResults.length - 1
                            ? () => _switchToResult(_currentIndex + 1)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _creativeDownloadButton(
                        isLoading: _saving,
                        onTap: _saving ? null : _saveToPhotos,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _creativeHomeButton(
                        onTap: _saving
                            ? null
                            : () =>
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  Approute.welcome,
                                  (route) => false,
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.65,
                    maxScale: 2.5,
                    boundaryMargin: const EdgeInsets.all(100),
                    child: AnimatedScale(
                      scale: _badgeScale,
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutBack,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
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
        ),
      ),
    );
  }
}

class _TopSnackBarWidget extends StatefulWidget {
  final String message;
  final bool isSuccess;
  final VoidCallback onDismiss;

  const _TopSnackBarWidget({
    required this.message,
    required this.isSuccess,
    required this.onDismiss,
  });

  @override
  State<_TopSnackBarWidget> createState() => _TopSnackBarWidgetState();
}

class _TopSnackBarWidgetState extends State<_TopSnackBarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 260),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        await _hide();
      }
    });
  }

  Future<void> _hide() async {
    if (!_controller.isDismissed) {
      await _controller.reverse();
    }
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top + 10;

    final gradientColors = widget.isSuccess
        ? const [Color(0xFF11998E), Color(0xFF38EF7D)]
        : const [Color(0xFFE53935), Color(0xFFFF6F61)];

    final glowColor =
        widget.isSuccess ? const Color(0xFF11998E) : const Color(0xFFE53935);

    final icon =
        widget.isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;

    final title = widget.isSuccess ? "ជោគជ័យ" : "បរាជ័យ";

    return Positioned(
      top: topInset,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withOpacity(0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.28),
                  width: 1.1,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _hide,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoIStyleBadge extends StatelessWidget {
  final String fullName;
  final String phone;
  final String code;
  final String token;
  final String userTypeText;
  final String rawUserType;
  final String parkingRequestStatus;
  final List vehicles;
  final Map? workingInfo;
  final Uint8List? selfieBytes;
  final String selfiePath;
  final Uint8List? qrBytes;
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
    required this.rawUserType,
    required this.parkingRequestStatus,
    required this.vehicles,
    required this.workingInfo,
    required this.selfieBytes,
    required this.selfiePath,
    required this.qrBytes,
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

    final ministry = rawUserType == "GUEST"
        ? pick(["organization", "generalDepartmentText", "generalDepartment"])
        : pick(["generalDepartment", "generalDepartmentText", "organization"]);

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
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFFFFF), Color(0xFFF2F6FF)],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.10,
                    child: Center(
                      child: Image.asset(
                        "assets/img/logo_moi.png",
                        width: 620,
                        height: 620,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
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
                        child: Image.asset(
                          "assets/img/logo_moi.png",
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      const SizedBox(width: 18),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "ក្រសួងមហាផ្ទៃ",
                              style: TextStyle(
                                color: _gold,
                                fontWeight: FontWeight.w900,
                                fontSize: 36,
                                height: 1.0,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              "MINISTRY OF INTERIOR",
                              style: TextStyle(
                                color: _gold,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                letterSpacing: 0.6,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 100),
                      const Text(
                        "បណ្ណចេញ/ចូល",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF06175F),
                          letterSpacing: 0.5,
                          height: 1.2,
                          fontFamily: 'khmer moul light',
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black54, width: 2),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: qrBytes == null
                            ? const Center(
                                child: Text(
                                  "NO QR",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black54,
                                  ),
                                ),
                              )
                            : Image.memory(
                                qrBytes!,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 36,
                  right: 36,
                  top: 170,
                  child: Container(height: 2, color: _line),
                ),
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
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          subcategory.isEmpty ? "-" : subcategory,
                          style: const TextStyle(
                            color: _navy,
                            fontWeight: FontWeight.w900,
                            fontSize: 32,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          plate.isEmpty ? "-" : plate,
                          style: const TextStyle(
                            color: _navy,
                            fontWeight: FontWeight.w900,
                            fontSize: 40,
                            letterSpacing: 2,
                            height: 1.0,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 46,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: _cardBlue, width: 2),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            plateCode.isNotEmpty
                                ? plateCode
                                : (subcategory.isEmpty ? "-" : subcategory),
                            style: const TextStyle(
                              color: _footerRed,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 380,
                  right: 46,
                  top: 210,
                  bottom: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 62,
                        color: _navy,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                "ព័ត៌មានផ្ទាល់ខ្លួន",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                ),
                              ),
                            ),
                            Text(
                              code.isEmpty ? "GDDTM###########" : code,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _twoColRowSafe(
                        leftLabel: "នាមត្រកូល និងនាមខ្លួន",
                        leftValue: fullName,
                        rightLabel: "ប្រភេទមន្ត្រី",
                        rightValue: userTypeText,
                      ),
                      const SizedBox(height: 14),
                      if (showPoliceId) ...[
                        _twoColRowSafe(
                          leftLabel: "អត្តលេខ",
                          leftValue: policeId,
                          rightLabel: "",
                          rightValue: "",
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (showProvince) ...[
                        _twoColRowSafe(
                          leftLabel: "ខេត្ត/រាជធានី",
                          leftValue: provCity,
                          rightLabel: "",
                          rightValue: "",
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (showWorkInfo) ...[
                        _twoColRowSafe(
                          leftLabel: "ក្រសួង/ស្ថាប័ន",
                          leftValue: ministry,
                          rightLabel: "នាយកដ្ឋាន/អង្គភាព",
                          rightValue: dept,
                        ),
                        const SizedBox(height: 14),
                        _twoColRowSafe(
                          leftLabel: "ការិយាល័យ",
                          leftValue: office,
                          rightLabel: "តួនាទី",
                          rightValue: position,
                        ),
                        const SizedBox(height: 14),
                      ],
                      _blueSectionTitle("ព័ត៌មាន ${vehicleTypeKh(vehicleType)}"),
                      const SizedBox(height: 12),
                      _twoColRowSafe(
                        leftLabel: "ស្លាកលេខ",
                        leftValue: plate,
                        rightLabel: "ម៉ាក",
                        rightValue: brand,
                      ),
                      const SizedBox(height: 14),
                      _twoColRowSafe(
                        leftLabel: "ឆ្នាំផលិត",
                        leftValue: year,
                        rightLabel: "លេខទូរស័ព្ទ",
                        rightValue: phone,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: const [
                          Text(
                            "សុពលភាពពី ",
                            style: TextStyle(
                              color: Color(0xFF8A94A6),
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              height: 1.0,
                            ),
                          ),
                          Spacer(),
                          Text(
                            "សុពលភាពដល់ ",
                            style: TextStyle(
                              color: Color(0xFF8A94A6),
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "ថ្ងៃទី $issueDateStr",
                              style: const TextStyle(
                                color: _footerRed,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              "ថ្ងៃទី $expiryDateStr",
                              style: const TextStyle(
                                color: _navy,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 22,
        ),
      ),
    );
  }

  static Widget _twoColRowSafe({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
  }) {
    Widget cell({
      required String label,
      required String value,
      required CrossAxisAlignment align,
      required TextAlign textAlign,
    }) {
      return Expanded(
        child: Column(
          crossAxisAlignment: align,
          children: [
            Text(
              label,
              textAlign: textAlign,
              style: const TextStyle(
                color: Color(0xFF8A94A6),
                fontWeight: FontWeight.w800,
                fontSize: 18,
                height: 1.0,
              ),
            ),
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
                      height: 1.08,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cell(
          label: leftLabel,
          value: leftValue,
          align: CrossAxisAlignment.start,
          textAlign: TextAlign.left,
        ),
        const SizedBox(width: 32),
        cell(
          label: rightLabel,
          value: rightValue,
          align: CrossAxisAlignment.end,
          textAlign: TextAlign.right,
        ),
      ],
    );
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
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 34,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  static Widget _badgePhoto(Uint8List? bytes, String path) {
    Widget fallback() => const Center(
          child: Icon(Icons.person, size: 80, color: Color(0xFF9AA6B2)),
        );

    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }

    if (path.isNotEmpty && File(path).existsSync()) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }

    return fallback();
  }
}