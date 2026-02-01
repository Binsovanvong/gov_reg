import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gov_reg/routes/approute.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ✅ MUST be top-level (NOT inside State class)
class _VehicleForm {
  final brand = TextEditingController();
  final plate = TextEditingController();
  final color = TextEditingController();
  final year = TextEditingController();

  /// ✅ already exists in your app
  String vehicleType = "CAR";

  /// ✅ CAR plate types
  String carPlateType = "NORMAL_CAR";

  /// ✅ MOTO plate types
  String motoPlateType = "NORMAL_MOTO";

  void dispose() {
    brand.dispose();
    plate.dispose();
    color.dispose();
    year.dispose();
  }
}

/// =======================
/// ✅ Dropdown Models
/// =======================
class GeneralDepartmentItem {
  final int id;
  final String name;

  GeneralDepartmentItem({required this.id, required this.name});

  factory GeneralDepartmentItem.fromJson(Map<String, dynamic> json) {
    return GeneralDepartmentItem(
      id: (json['id'] ?? 0) is int
          ? (json['id'] ?? 0) as int
          : int.tryParse("${json['id']}") ?? 0,
      name: (json['name'] ?? '') as String,
    );
  }
}

class DepartmentItem {
  final int id;
  final String name;
  final int generalDepartmentId;

  DepartmentItem({
    required this.id,
    required this.name,
    required this.generalDepartmentId,
  });

  factory DepartmentItem.fromJson(Map<String, dynamic> json) {
    final gd = json['generalDepartment'] as Map<String, dynamic>?;
    final gdId = (json['generalDepartmentId'] ?? gd?['id'] ?? 0);

    return DepartmentItem(
      id: (json['id'] ?? 0) is int
          ? (json['id'] ?? 0) as int
          : int.tryParse("${json['id']}") ?? 0,
      name: (json['name'] ?? '') as String,
      generalDepartmentId: gdId is int ? gdId : int.tryParse("$gdId") ?? 0,
    );
  }
}

class BurauItem {
  final int id;
  final String name;
  final int departmentId;

  BurauItem({
    required this.id,
    required this.name,
    required this.departmentId,
  });

  factory BurauItem.fromJson(Map<String, dynamic> json) {
    final dept = json['department'] as Map<String, dynamic>?;
    final deptId = (json['departmentId'] ?? dept?['id'] ?? 0);

    return BurauItem(
      id: (json['id'] ?? 0) is int
          ? (json['id'] ?? 0) as int
          : int.tryParse("${json['id']}") ?? 0,
      name: (json['name'] ?? '') as String,
      departmentId: deptId is int ? deptId : int.tryParse("$deptId") ?? 0,
    );
  }
}

class PositionItem {
  final int id;
  final String name;

  PositionItem({required this.id, required this.name});

  factory PositionItem.fromJson(Map<String, dynamic> json) {
    return PositionItem(
      id: (json['id'] ?? 0) is int
          ? (json['id'] ?? 0) as int
          : int.tryParse("${json['id']}") ?? 0,
      name: (json['name'] ?? '') as String,
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const String baseUrl = "http://10.0.2.2:8080";

  static const List<String> allowedUserTypes = [
    "GUEST",
    "INSIDE_OFFICER",
    "OUTSIDE_OFFICER",
    "SECRETARY",
    "DEPUTY_SECRETARY",
    "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER",
  ];

  /// ✅ Backend requires attachmentTypes for EACH file uploaded
  static const String attachmentTypeValue = "VEHICLE_DOCUMENT";

  String _userType = "GUEST";
  bool isLoading = false;

  // ✅ ONLY 2 attachment inputs:
  // 1) Multi files up to 5
  static const int maxFiles = 5;
  final List<File> attachFiles = [];
  final List<String> attachFileNames = [];
  String? attachFilesError;

  // 2) Camera (Selfie required only for Guest)
  File? cameraFile;
  String? cameraFileName;
  String? cameraError;
  final ImagePicker _imagePicker = ImagePicker();

  // Controllers
  final fullNameController = TextEditingController();
  final idNumberController = TextEditingController();
  final ministryController = TextEditingController();
  final departmentController = TextEditingController();
  final officeController = TextEditingController();
  final positionController = TextEditingController();
  final phoneController = TextEditingController();

  /// calendar date (yyyy-MM-dd) - only for NON duration types
  final requestDateController = TextEditingController();

  final provinceCityController = TextEditingController();
  final reasonController = TextEditingController();

  /// ✅ duration days input (used for NATIONAL + GUEST)
  final durationDaysController = TextEditingController();

  // Vehicles list
  final List<_VehicleForm> vehicles = [_VehicleForm()];

  // ----------------------------
  // ✅ Work dropdown state
  // ----------------------------
  bool dropdownLoading = false;

  List<GeneralDepartmentItem> gdList = [];
  List<DepartmentItem> deptList = [];
  List<BurauItem> burauAll = [];
  List<BurauItem> burauFiltered = [];
  List<PositionItem> posList = [];

  GeneralDepartmentItem? selectedGD;
  DepartmentItem? selectedDept;
  BurauItem? selectedBurau;
  PositionItem? selectedPos;

  // ----------------------------
  // Plate Types
  // ----------------------------

  /// ✅ CAR plate types
  final List<Map<String, String>> carPlateTypes = [
    {
      "key": "NORMAL_CAR",
      "label": "រថយន្តធម្មតា (2AB-1234)",
      "pattern": r"^2[A-Z]{2}-\d{4}$"
    },
    {"key": "CAR_STATE", "label": "រដ្ឋ (2-0369)", "pattern": r"^2-\d{4}$"},
    {"key": "CAR_POLICE", "label": "ប៉ូលីស (L-1077)", "pattern": r"^L-\d{4}$"},
    {
      "key": "CAR_DIPLOMAT",
      "label": "ការទូត (CD.76.002)",
      "pattern": r"^CD\.\d{2}\.\d{3}$"
    },
    {"key": "CAR_TRUCK", "label": "ឡានធំ (3A-1070)", "pattern": r"^3[A-Z]-\d{4}$"},
  ];

  /// ✅ MOTO plate types
  final List<Map<String, String>> motoPlateTypes = [
    {
      "key": "NORMAL_MOTO",
      "label": "ម៉ូតូធម្មតា (1AB-1234)",
      "pattern": r"^1[A-Z]{2}-\d{4}$"
    },
    {"key": "MOTO_STATE", "label": "ម៉ូតូរដ្ឋ (1-0369)", "pattern": r"^1-\d{4}$"},
    {"key": "MOTO_POLICE", "label": "ម៉ូតូប៉ូលីស (M-1234)", "pattern": r"^M-\d{4}$"},
  ];

  // ----------------------------
  // ✅ Rules (UPDATED for SECRETARY/DEPUTY)
  // ----------------------------
  bool get isGuest => _userType == "GUEST";
  bool get isInsideOfficer => _userType == "INSIDE_OFFICER";
  bool get isOutsideOfficer => _userType == "OUTSIDE_OFFICER";
  bool get isOfficer => isInsideOfficer || isOutsideOfficer;

  bool get isSecretaryOrDeputy =>
      _userType == "SECRETARY" || _userType == "DEPUTY_SECRETARY";

  bool get isNational => _userType == "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER";

  static const bool showWorkFieldsForGuest = true;

  /// ✅ Only officers show ID number
  bool get showIdNumber => isOfficer;
  bool get showWorkFields => isOfficer || (isGuest && showWorkFieldsForGuest);
  bool get showProvinceCity =>
      _userType == "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER";

  /// ✅ Work fields ONLY for Officer + National + Guest(optional)
  /// ❌ SECRETARY/DEPUTY: hidden
  bool get showWorkFields => isOfficer || isNational || (isGuest && showWorkFieldsForGuest);

  /// ✅ Province only for NATIONAL
  bool get showProvinceCity => isNational;

  /// ✅ GUEST + NATIONAL use duration days input
  bool get useDurationDays => isNational || isGuest;

  /// ✅ Guest required selfie, other user types optional
  bool get selfieRequired => isGuest;

  /// ✅ Dropdown ONLY for officers
  bool get useWorkDropdown => isOfficer;

  // ----------------------------
  // AUTH
  // ----------------------------
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("accessToken");
  }

  Future<String?> _getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("refreshToken");
  }

  static const String refreshPath = "/api/v1/auth/refresh";

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final uri = Uri.parse("$baseUrl$refreshPath");

    final res = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $refreshToken",
      },
      body: jsonEncode({
        "refreshToken": refreshToken,
        "token": refreshToken,
      }),
    );

    if (res.statusCode != 200) {
      debugPrint("Refresh failed: ${res.statusCode} ${res.body}");
      return null;
    }

    final data = jsonDecode(res.body);
    String newAccessToken = "";

    if (data is Map) {
      newAccessToken = (data["accessToken"] ?? data["token"] ?? "").toString();
      if (newAccessToken.isEmpty && data["token"] is Map) {
        newAccessToken =
            (data["token"]["accessToken"] ?? data["token"]["token"] ?? "").toString();
      }
    }

    if (newAccessToken.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("accessToken", newAccessToken);
    return newAccessToken;
  }

  Future<void> forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("accessToken");
    await prefs.remove("refreshToken");
    await prefs.clear();
    if (!mounted) return;
    _snack("Session expired. Please login again.");
    // Navigator.pushReplacementNamed(context, Approute.loginScreen);
  }

  Future<http.Response> _getWithAuthRetry(Uri uri) async {
    final prefs = await SharedPreferences.getInstance();
    String token = prefs.getString("accessToken") ?? "";

    Future<http.Response> doGet(String t) {
      return http.get(
        uri,
        headers: {
          "Accept": "application/json",
          if (t.isNotEmpty) "Authorization": "Bearer $t",
        },
      );
    }

    var res = await doGet(token);

    if (res.statusCode == 401 &&
        (res.body.contains("JWT token has expired") || res.body.contains("JWT expired"))) {
      final newToken = await _refreshAccessToken();
      if (newToken == null || newToken.isEmpty) {
        await forceLogout();
        return res;
      }
      res = await doGet(newToken);
    }

    if (res.statusCode == 401) {
      await forceLogout();
    }

    return res;
  }

  // ----------------------------
  // Work dropdown APIs
  // ----------------------------
  Future<List<GeneralDepartmentItem>> fetchGeneralDepartments() async {
    final uri = Uri.parse("$baseUrl/api/v1/general-departments");
    final res = await _getWithAuthRetry(uri);
    if (res.statusCode != 200) {
      throw "GeneralDepartments HTTP ${res.statusCode}: ${res.body}";
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .map((e) => GeneralDepartmentItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DepartmentItem>> fetchDepartmentsByGeneralDepartment(int gdId) async {
    final uri = Uri.parse("$baseUrl/api/v1/departments/general-department/$gdId");
    final res = await _getWithAuthRetry(uri);
    if (res.statusCode != 200) {
      throw "Departments HTTP ${res.statusCode}: ${res.body}";
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded.map((e) => DepartmentItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BurauItem>> fetchBuraus() async {
    final uri = Uri.parse("$baseUrl/api/v1/buraus");
    final res = await _getWithAuthRetry(uri);
    if (res.statusCode != 200) {
      throw "Buraus HTTP ${res.statusCode}: ${res.body}";
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded.map((e) => BurauItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<PositionItem>> fetchPositions() async {
    final uri = Uri.parse("$baseUrl/api/v1/positions");
    final res = await _getWithAuthRetry(uri);
    if (res.statusCode != 200) {
      throw "Positions HTTP ${res.statusCode}: ${res.body}";
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded.map((e) => PositionItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _loadWorkDropdownsIfNeeded() async {
    if (!useWorkDropdown) return;

    setState(() => dropdownLoading = true);
    try {
      final gds = await fetchGeneralDepartments();
      final buraus = await fetchBuraus();
      final positions = await fetchPositions();

      if (!mounted) return;
      setState(() {
        gdList = gds;
        burauAll = buraus;
        posList = positions;
      });
    } catch (e) {
      debugPrint("Dropdown load error: $e");
      if (mounted) _snack("Dropdown load error: $e");
    } finally {
      if (mounted) setState(() => dropdownLoading = false);
    }
  }

  void _resetWorkDropdownStateAndControllers() {
    selectedGD = null;
    selectedDept = null;
    selectedBurau = null;
    selectedPos = null;

    deptList = [];
    burauFiltered = [];

    ministryController.clear();
    departmentController.clear();
    officeController.clear();
    positionController.clear();
  }

  Future<void> onSelectGD(GeneralDepartmentItem? gd) async {
    setState(() {
      selectedGD = gd;

      selectedDept = null;
      selectedBurau = null;
      deptList = [];
      burauFiltered = [];

      ministryController.text = gd?.name ?? "";
      departmentController.clear();
      officeController.clear();
    });

    if (gd == null) return;

    try {
      setState(() => dropdownLoading = true);
      final deps = await fetchDepartmentsByGeneralDepartment(gd.id);
      if (!mounted) return;
      setState(() => deptList = deps);
    } catch (e) {
      debugPrint("Departments load error: $e");
      if (mounted) _snack("Load departments error: $e");
    } finally {
      if (mounted) setState(() => dropdownLoading = false);
    }
  }

  void onSelectDept(DepartmentItem? d) {
    setState(() {
      selectedDept = d;
      selectedBurau = null;

      departmentController.text = d?.name ?? "";
      officeController.clear();

      burauFiltered = burauAll.where((b) => b.departmentId == (d?.id ?? -1)).toList();
    });
  }

  void onSelectBurau(BurauItem? b) {
    setState(() {
      selectedBurau = b;
      officeController.text = b?.name ?? "";
    });
  }

  void onSelectPosition(PositionItem? p) {
    setState(() {
      selectedPos = p;
      positionController.text = p?.name ?? "";
    });
  }

  // ----------------------------
  // Helpers
  // ----------------------------
  String _normalizePlate(String s) =>
      s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// ✅ yyyy-MM-dd (UI)
  String _fmtYmd(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// yyyymmdd int
  int _fmtYmdInt(DateTime d) =>
      int.parse("${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}");

  /// ✅ dd-MM-yyyy (Backend expects this for LocalDate)
  String _fmtDmy(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";

  // ✅ Multi-file picker (max 5)
  Future<void> pickAttachFiles() async {
    setState(() => attachFilesError = null);

    if (attachFiles.length >= maxFiles) {
      setState(() => attachFilesError = "អាចភ្ជាប់បានតែ ៥ ឯកសារ");
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf'],
      allowMultiple: true,
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    for (final f in result.files) {
      if (attachFiles.length >= maxFiles) break;
      if (f.path == null) continue;

      final file = File(f.path!);

      const maxBytes = 5 * 1024 * 1024;
      final bytes = await file.length();
      if (bytes > maxBytes) {
        setState(() => attachFilesError = "ឯកសារត្រូវ ≤ 5MB");
        return;
      }

      final ext = (f.extension ?? "").toLowerCase();
      if (!['png', 'jpg', 'jpeg', 'pdf'].contains(ext)) {
        setState(() => attachFilesError = "ប្រភេទឯកសារមិនត្រឹមត្រូវ");
        return;
      }

      if (attachFiles.any((x) => x.path == file.path)) continue;

      attachFiles.add(file);
      attachFileNames.add(f.name);
    }

    setState(() {});
  }

  void removeAttachFileAt(int i) {
    setState(() {
      attachFiles.removeAt(i);
      attachFileNames.removeAt(i);
    });
  }

  // ✅ Camera (optional except guest)
  Future<void> pickCameraImage() async {
    setState(() => cameraError = null);

    final XFile? xfile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (xfile == null) return;

    final file = File(xfile.path);

    const maxBytes = 5 * 1024 * 1024;
    final bytes = await file.length();
    if (bytes > maxBytes) {
      setState(() => cameraError = "រូបភាពត្រូវ ≤ 5MB");
      return;
    }

    setState(() {
      cameraFile = file;
      cameraFileName = xfile.name;
    });
  }

  void clearCamera() {
    setState(() {
      cameraFile = null;
      cameraFileName = null;
      cameraError = null;
    });
  }

  @override
  void dispose() {
    fullNameController.dispose();
    idNumberController.dispose();
    ministryController.dispose();
    departmentController.dispose();
    officeController.dispose();
    positionController.dispose();
    phoneController.dispose();
    requestDateController.dispose();
    provinceCityController.dispose();
    reasonController.dispose();
    durationDaysController.dispose();

    for (final v in vehicles) {
      v.dispose();
    }
    super.dispose();
  }

  // ----------------------------
  // Plate validation helper
  // ----------------------------
  bool _isPlateValid(_VehicleForm v) {
    final plateValue = _normalizePlate(v.plate.text);

    if (v.vehicleType == "MOTORBIKE") {
      final selected = motoPlateTypes.firstWhere((t) => t["key"] == v.motoPlateType);
      final reg = RegExp(selected["pattern"]!);
      return reg.hasMatch(plateValue);
    } else {
      final selected = carPlateTypes.firstWhere((t) => t["key"] == v.carPlateType);
      final reg = RegExp(selected["pattern"]!);
      return reg.hasMatch(plateValue);
    }
  }

  String _plateHint(_VehicleForm v) {
    if (v.vehicleType == "MOTORBIKE") {
      final selected = motoPlateTypes.firstWhere((t) => t["key"] == v.motoPlateType);
      return selected["label"]!;
    } else {
      final selected = carPlateTypes.firstWhere((t) => t["key"] == v.carPlateType);
      return selected["label"]!;
    }
  }

  // ----------------------------
  // validateForm
  // ----------------------------
  bool validateForm() {
    if (fullNameController.text.trim().isEmpty) {
      _snack("សូមបញ្ចូលឈ្មោះពេញ");
      return false;
    }

    if (showIdNumber) {
      final policeId = idNumberController.text.trim();

      if (policeId.isEmpty) {
        _snack("សូមបញ្ចូលអត្តលេខ");
        return false;
      }

      if (!RegExp(r'^\d+$').hasMatch(policeId)) {
        _snack("អត្តលេខត្រូវមានតែលេខ");
        return false;
      }

      if (policeId.length > 10) {
        _snack("អត្តលេខមិនអាចលើស ១០ ខ្ទង់បានទេ");
        return false;
      }
    }

    if (phoneController.text.trim().isEmpty) {
      _snack("សូមបញ្ចូលលេខទូរស័ព្ទ");
      return false;
    }

    // ✅ GUEST + NATIONAL use duration
    if (useDurationDays) {
      final durText = durationDaysController.text.trim();
      if (durText.isEmpty) {
        _snack("សូមបញ្ចូលរយៈពេល (ចំនួនថ្ងៃ)");
        return false;
      }
      final dur = int.tryParse(durText);
      if (dur == null || dur <= 0) {
        _snack("រយៈពេលត្រូវជាលេខ > 0");
        return false;
      }
      if (dur > 365) {
        _snack("រយៈពេលមិនអាចលើស 365 ថ្ងៃ");
        return false;
      }
    } else {
      if (requestDateController.text.trim().isEmpty) {
        _snack("សូមជ្រើសកាលបរិច្ឆេទស្នើរ");
        return false;
      }
    }

    if (showWorkFields) {
      if (useWorkDropdown) {
        if (selectedGD == null) {
          _snack("សូមជ្រើសក្រសួង/ស្ថាប័ន");
          return false;
        }
        if (selectedDept == null) {
          _snack("សូមជ្រើសនាយកដ្ឋាន/អង្គភាព");
          return false;
        }
        if (selectedBurau == null) {
          _snack("សូមជ្រើសការិយាល័យ");
          return false;
        }
        if (selectedPos == null) {
          _snack("សូមជ្រើសតួនាទី");
          return false;
        }
      } else {
        if (ministryController.text.trim().isEmpty) {
          _snack("សូមបញ្ចូលក្រសួង/ស្ថាប័ន");
          return false;
        }
        if (departmentController.text.trim().isEmpty) {
          _snack("សូមបញ្ចូលនាយកដ្ឋាន/អង្គភាព");
          return false;
        }
        if (officeController.text.trim().isEmpty) {
          _snack("សូមបញ្ចូលការិយាល័យ");
          return false;
        }
        if (positionController.text.trim().isEmpty) {
          _snack("សូមបញ្ចូលតួនាទី");
          return false;
        }
      }
    }

    if (showProvinceCity && provinceCityController.text.trim().isEmpty) {
      _snack("សូមបញ្ចូលខេត្ត/រាជធានី");
      return false;
    }

    for (int i = 0; i < vehicles.length; i++) {
      final v = vehicles[i];

      if (v.brand.text.trim().isEmpty) {
        _snack("សូមបញ្ចូលម៉ាក (#${i + 1})");
        return false;
      }

      if (_normalizePlate(v.plate.text).isEmpty) {
        _snack("សូមបញ្ចូលស្លាកលេខ (#${i + 1})");
        return false;
      }

      if (!_isPlateValid(v)) {
        _snack("ស្លាកលេខ (#${i + 1}) មិនត្រឹមត្រូវ: ${_plateHint(v)}");
        return false;
      }

      if (v.color.text.trim().isEmpty) {
        _snack("សូមបញ្ចូលពណ៌ (#${i + 1})");
        return false;
      }

      final year = int.tryParse(v.year.text.trim());
      if (year == null || year < 1900) {
        _snack("ឆ្នាំផលិតមិនត្រឹមត្រូវ (#${i + 1})");
        return false;
      }
    }

    if (selfieRequired && cameraFile == null) {
      setState(() => cameraError = "សូមថតរូប Selfie (ចាំបាច់)");
      return false;
    }

    return true;
  }

  // ----------------------------
  // API
  // ----------------------------
  Future<Map<String, dynamic>> createParkingCardRequest() async {
    final base = Uri.parse("$baseUrl/api/v1/parking-card-requests");

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime requestAt;
    DateTime requestEnd;

    // ✅ duration for GUEST + NATIONAL
    if (useDurationDays) {
      final dur = int.parse(durationDaysController.text.trim());
      requestAt = today;
      requestEnd = today.add(Duration(days: dur));
    } else {
      final chosen = DateTime.parse(requestDateController.text.trim()); // yyyy-MM-dd
      requestAt = chosen;
      requestEnd = chosen;
    }

    final int requestDateInt = _fmtYmdInt(requestEnd);

    // ✅ FIX: backend expects dd-MM-yyyy for LocalDate
    final String requestAtDateStr = _fmtDmy(requestAt);

    final dto = <String, dynamic>{
      "reason": reasonController.text.trim().isEmpty ? "Parking card request" : reasonController.text.trim(),
      "requestDate": requestDateInt,
      "user": <String, dynamic>{
        "name": fullNameController.text.trim(),
        "phone": phoneController.text.trim(),
        "userType": _userType,
      },
      "vehicles": vehicles.map((v) {
        return <String, dynamic>{
          "brand": v.brand.text.trim(),
          "plateNumber": _normalizePlate(v.plate.text),
          "color": v.color.text.trim(),
          "madeYear": int.tryParse(v.year.text.trim()) ?? 0,
          "vehicleType": v.vehicleType,
        };
      }).toList(),
      "requestDate": requestDateController.text.trim(),
      "reason": reasonController.text.trim().isEmpty
          ? "Parking card request"
          : reasonController.text.trim(),
    };

    /// ✅ GUEST -> DO NOT send requestAtDate (only requestDate)
    if (_userType != "GUEST") {
      dto["requestAtDate"] = requestAtDateStr;
    }

    // workingInfo
    final wi = <String, dynamic>{};
    if (showIdNumber) wi["policeId"] = idNumberController.text.trim();

    if (showWorkFields) {
      wi["generalDepartmentText"] = ministryController.text.trim();
      wi["departmentText"] = departmentController.text.trim();
      wi["burauText"] = officeController.text.trim();
      wi["positionText"] = positionController.text.trim();
    }

    if (showProvinceCity) {
      wi["provinceCity"] = provinceCityController.text.trim();
    }

    if (wi.isNotEmpty) {
      (dto["user"] as Map<String, dynamic>)["workingInfo"] = wi;
    }

    // ✅ Token OPTIONAL (guest can submit without login)
    final token = await _getToken(); // may be null/empty

    // ✅ Collect files (multi + camera only)
    final List<Map<String, String>> fileList = [];

    for (int i = 0; i < attachFiles.length; i++) {
      fileList.add({"path": attachFiles[i].path, "name": attachFileNames[i]});
    }

    if (cameraFile != null) {
      fileList.add({
        "path": cameraFile!.path,
        "name": cameraFileName ?? cameraFile!.path.split('/').last,
      });
    }

    // ✅ attachmentTypes count must match file count
    Uri uri = base;
    if (fileList.isNotEmpty) {
      uri = base.replace(
        queryParameters: <String, dynamic>{
          "attachmentTypes":
              List<String>.filled(fileList.length, attachmentTypeValue),
        },
      );
    }

    final request = http.MultipartRequest("POST", uri);
    request.headers["Accept"] = "*/*";

    // ✅ Only send Authorization if token exists
    if (token != null && token.isNotEmpty) {
      request.headers["Authorization"] = "Bearer $token";
    }

    request.files.add(
      http.MultipartFile.fromString(
        "dto",
        jsonEncode(dto),
        filename: "dto.json",
        contentType: MediaType('application', 'json'),
      ),
    );

    for (final f in fileList) {
      request.files.add(
        await http.MultipartFile.fromPath(
          "files",
          f["path"]!,
          filename: f["name"]!,
        ),
      );
    }

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw "HTTP ${resp.statusCode}: ${resp.body.isEmpty ? '(empty body)' : resp.body}";
    }

    if (resp.body.isEmpty) return {};
    final decoded = jsonDecode(resp.body);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  // ----------------------------
  // Submit
  // ----------------------------
  Future<void> submitRegister() async {
    if (!validateForm()) return;

    setState(() => isLoading = true);
    try {
      final res = await createParkingCardRequest();

      final code = (res["code"] ?? "").toString();

      String token = "";
      final t = res["token"];
      if (t is String) token = t;
      if (t is Map) token = (t["accessToken"] ?? t["token"] ?? "").toString();

      if (!mounted) return;

      // ✅ read selfie bytes (BEST)
      Uint8List? selfieBytes;
      if (cameraFile != null) {
        selfieBytes = await cameraFile!.readAsBytes();
      }

      Navigator.pushNamed(
        context,
        Approute.verifySuccessScreen,
        arguments: {
          "code": code,
          "token": token,

          // ✅ personal
          "fullName": fullNameController.text.trim(),
          "phone": phoneController.text.trim(),
          "userType": _userType,

          // ✅ selfie (TOP LEVEL ✅)
          "selfieBytes": selfieBytes,
          "selfiePath": cameraFile?.path, // optional backup

          // ✅ working info (texts)
          "workingInfo": {
            "generalDepartmentText": ministryController.text.trim(),
            "departmentText": departmentController.text.trim(),
            "burauText": officeController.text.trim(),
            "positionText": positionController.text.trim(),
            "policeId": idNumberController.text.trim(),
            "provinceCity": provinceCityController.text.trim(),
          },

          // ✅ vehicles list (NO selfie here)
          "vehicles": vehicles.map((v) => {
                "brand": v.brand.text.trim(),
                "plateNumber": v.plate.text.trim(),
                "color": v.color.text.trim(),
                "madeYear": int.tryParse(v.year.text.trim()) ?? 0,
                "vehicleType": v.vehicleType,
              }).toList(),
        },
      );
    } catch (e, st) {
      debugPrint("SUBMIT ERROR: $e");
      debugPrint("STACK: $st");
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ----------------------------
  // Date picker (NON duration)
  // ----------------------------
  void pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (d != null) {
      requestDateController.text = _fmtYmd(d); // yyyy-MM-dd
    }
  }

  // ----------------------------
  // UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    if (!allowedUserTypes.contains(_userType)) _userType = "GUEST";

    return Scaffold(
      backgroundColor: const Color(0xFFDFB73B),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 130),
                child: Column(
                  children: [
                    _header(),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sectionTitle("ព័ត៌មានផ្ទាល់ខ្លួន"),
                            dropdownUserType(),
                            const SizedBox(height: 15),

                            if (showIdNumber)
                              twoInputRow(
                                "គោត្តនាម និងនាម",
                                "អត្តលេខ",
                                "បញ្ចូលឈ្មោះពេញ",
                                "បញ្ចូលអត្តលេខ",
                                fullNameController,
                                idNumberController,
                                leftIsPlate: false,
                                rightIsPlate: false,
                              )
                            else
                              oneInput(
                                label: "គោត្តនាម និងនាម",
                                hint: "បញ្ចូលឈ្មោះពេញ",
                                controller: fullNameController,
                              ),

                            if (showWorkFields) ...[
                              sectionTitle("ព័ត៌មានការងារ"),

                              /// ✅ Officers -> dropdown
                              if (useWorkDropdown) ...[
                                if (dropdownLoading)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    child: LinearProgressIndicator(),
                                  ),
                                _ddGeneralDepartment(),
                                _ddDepartment(),
                                _ddBurau(),
                                _ddPosition(),
                              ] else ...[
                                /// ✅ Guest + National -> text fields
                                twoInputRow(
                                  "ក្រសួង/ស្ថាប័ន",
                                  "នាយកដ្ឋាន/អង្គភាព",
                                  "បញ្ចូលក្រសួង",
                                  "បញ្ចូលនាយកដ្ឋាន",
                                  ministryController,
                                  departmentController,
                                  leftIsPlate: false,
                                  rightIsPlate: false,
                                ),
                                twoInputRow(
                                  "ការិយាល័យ",
                                  "តួនាទី",
                                  "បញ្ចូលការិយាល័យ",
                                  "បញ្ចូលតួនាទី",
                                  officeController,
                                  positionController,
                                  leftIsPlate: false,
                                  rightIsPlate: false,
                                ),
                              ],
                            ],

                            if (showProvinceCity)
                              oneInput(
                                label: "ខេត្ត/រាជធានី",
                                hint: "បញ្ចូលខេត្ត/រាជធានី",
                                controller: provinceCityController,
                              ),

                            const SizedBox(height: 10),
                            Rowlabel(),
                            const SizedBox(height: 10),
                            phoneAndDate(),
                            oneInput(
                              label: "ហេតុផលស្នេីរសំុ",
                              controller: reasonController,
                              hint: "ហេតុផល"
                            ),
                            const SizedBox(height: 10),

                            sectionTitle("ព័ត៌មានរថយន្ត/ម៉ូតូ"),
                            ...List.generate(vehicles.length, (i) {
                              final v = vehicles[i];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 6),
                                    child: Row(
                                      children: [
                                        Text(
                                          "រថយន្ត/ម៉ូតូ #${i + 1}",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const Spacer(),
                                        if (vehicles.length > 1)
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () {
                                              setState(() {
                                                v.dispose();
                                                vehicles.removeAt(i);
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: RadioListTile<String>(
                                          value: "CAR",
                                          groupValue: v.vehicleType,
                                          title: const Text("រថយន្ត"),
                                          onChanged: (x) => setState(() {
                                            if (x != null) v.vehicleType = x;
                                          }),
                                        ),
                                      ),
                                      Expanded(
                                        child: RadioListTile<String>(
                                          value: "MOTORBIKE",
                                          groupValue: v.vehicleType,
                                          title: const Text("ម៉ូតូ"),
                                          onChanged: (x) => setState(() {
                                            if (x != null) v.vehicleType = x;
                                          }),
                                        ),
                                      ),
                                    ],
                                  ),
                                  oneInput(label: "ម៉ាក", hint: "បញ្ចូលម៉ាក", controller: v.brand),
                                  plateRow(v),
                                  twoInputRow(
                                    "ពណ៌",
                                    "ឆ្នាំផលិត",
                                    "ពណ៌រថយន្ត",
                                    "ឆ្នាំផលិត",
                                    v.color,
                                    v.year,
                                    leftIsPlate: false,
                                    rightIsPlate: false,
                                  ),
                                  const Divider(height: 24),
                                ],
                              );
                            }),

                            uploadMultiAttachment(),
                            uploadCameraAttachment(),
                            bottom(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ----------------------------
  // Work dropdown widgets
  // ----------------------------
  Widget _ddGeneralDepartment() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("ក្រសួង/ស្ថាប័ន"),
          const SizedBox(height: 6),
          DropdownButtonFormField<GeneralDepartmentItem>(
            isExpanded: true,
            value: selectedGD,
            decoration: inputDecoration("ជ្រើសក្រសួង/ស្ថាប័ន"),
            items: gdList
                .map((x) => DropdownMenuItem(
                      value: x,
                      child: Text(x.name, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (x) => onSelectGD(x),
          ),
        ],
      ),
    );
  }

  Widget _ddDepartment() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("នាយកដ្ឋាន/អង្គភាព"),
          const SizedBox(height: 6),
          DropdownButtonFormField<DepartmentItem>(
            isExpanded: true,
            value: selectedDept,
            decoration: inputDecoration("ជ្រើសនាយកដ្ឋាន/អង្គភាព"),
            items: deptList
                .map((x) => DropdownMenuItem(
                      value: x,
                      child: Text(x.name, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (x) => onSelectDept(x),
          ),
        ],
      ),
    );
  }

  Widget _ddBurau() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("ការិយាល័យ"),
          const SizedBox(height: 6),
          DropdownButtonFormField<BurauItem>(
            isExpanded: true,
            value: selectedBurau,
            decoration: inputDecoration("ជ្រើសការិយាល័យ"),
            items: burauFiltered
                .map((x) => DropdownMenuItem(
                      value: x,
                      child: Text(x.name, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (x) => onSelectBurau(x),
          ),
        ],
      ),
    );
  }

  Widget _ddPosition() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("តួនាទី"),
          const SizedBox(height: 6),
          DropdownButtonFormField<PositionItem>(
            isExpanded: true,
            value: selectedPos,
            decoration: inputDecoration("ជ្រើសតួនាទី"),
            items: posList
                .map((x) => DropdownMenuItem(
                      value: x,
                      child: Text(x.name, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (x) => onSelectPosition(x),
          ),
        ],
      ),
    );
  }

  // ----------------------------
  // Plate UI: CAR & MOTO
  // ----------------------------
  Widget plateRow(_VehicleForm v) {
    final isMoto = v.vehicleType == "MOTORBIKE";
    final items = isMoto ? motoPlateTypes : carPlateTypes;
    final currentType = isMoto ? v.motoPlateType : v.carPlateType;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isMoto ? "ស្លាកលេខម៉ូតូ" : "ស្លាកលេខរថយន្ត"),
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: currentType,
                  decoration: inputDecoration("ប្រភេទស្លាក"),
                  items: items.map((t) {
                    return DropdownMenuItem<String>(
                      value: t["key"],
                      child: Text(
                        t["label"]!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (x) {
                    if (x == null) return;
                    setState(() {
                      if (isMoto) {
                        v.motoPlateType = x;
                      } else {
                        v.carPlateType = x;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                flex: 3,
                child: TextFormField(
                  controller: v.plate,
                  decoration: inputDecoration("បញ្ចូលស្លាកលេខ"),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(12),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final up = newValue.text.toUpperCase();
                      return newValue.copyWith(
                        text: up,
                        selection: newValue.selection,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------
  // Attachment widgets
  // ----------------------------
  Widget uploadMultiAttachment() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isGuest
                ? "សូមថតឡានមុខក្រោយ (អតិបរមា $maxFiles ឯកសារ)"
                : "សូមថតកាតគ្រីឡាន, អត្តសញ្ញាណប័ណ្ណ​និងឯកសារពាក់ព័ន្ធ (អតិបរមា $maxFiles ឯកសារ)",
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: pickAttachFiles,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: attachFilesError != null
                      ? Colors.red
                      : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.upload_file, size: 40, color: Colors.green),
                  const SizedBox(height: 10),
                  Text(
                    "ចុចដើម្បីជ្រើសឯកសារ (${attachFiles.length}/$maxFiles)",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text("PNG, JPG, PDF (≤ 5MB)",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(attachFileNames.length, (i) {
            return Row(
              children: [
                Expanded(
                    child: Text(attachFileNames[i],
                        overflow: TextOverflow.ellipsis)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => removeAttachFileAt(i),
                ),
              ],
            );
          }),
          if (attachFilesError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                attachFilesError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget uploadCameraAttachment() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(selfieRequired
              ? "ថតរូប Selfie (ចាំបាច់)"
              : "ថតរូប Selfie (ជាជម្រើស)"),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: pickCameraImage,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color:
                      cameraError != null ? Colors.red : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.camera_alt, size: 40, color: Colors.blue),
                  SizedBox(height: 10),
                  Text("ចុចដើម្បីថតរូប",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text("Camera Image (≤ 5MB)",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
          if (cameraFileName != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child:
                        Text(cameraFileName!, overflow: TextOverflow.ellipsis)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: clearCamera,
                ),
              ],
            ),
          ],
          if (cameraError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                cameraError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // ----------------------------
  // Header + UI helpers
  // ----------------------------
  Widget _header() {
    return Container(
      height: 225,
      width: double.infinity,
      color: Colors.white,
      child: Column(
        children: const [
          SizedBox(height: 55),
          Row(
            children: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Image(
                  image: AssetImage('assets/img/about-moi-logo.png'),
                  height: 100,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ក្រសួងមហាផ្ទៃ',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xffDFB73B),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Ministry of Interior',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xffDFB73B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            "ប័ណ្ណស្នើរចំណតរថយន្ត",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              color: Color(0xffDD7B25),
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget dropdownUserType() {
    String labelOf(String v) {
      switch (v) {
        case "GUEST":
          return "ភ្ញៀវ";
        case "INSIDE_OFFICER":
          return "មន្រ្តីបំរើការងារនៅក្នុងទីស្តីការក្រសួងមហាឫ្ទៃ";
        case "OUTSIDE_OFFICER":
          return "មន្រ្តីបំរើការងារនៅក្រៅទីស្តីការក្រសួងមហាផ្ទៃ";
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: _userType,
        decoration: inputDecoration("ជ្រើសប្រភេទអ្នកប្រើប្រាស់"),
        items: allowedUserTypes
            .map((v) => DropdownMenuItem<String>(
                  value: v,
                  child: Text(labelOf(v), overflow: TextOverflow.ellipsis, maxLines: 2),
                ))
            .toList(),
        onChanged: (v) async {
          if (v == null) return;

          setState(() {
            _userType = v;

            // reset ids
            if (!(v == "INSIDE_OFFICER" || v == "OUTSIDE_OFFICER")) {
              idNumberController.clear();
            }

            // ✅ UPDATED: SECRETARY/DEPUTY should NOT show work fields
            final shouldShowWork = (v == "INSIDE_OFFICER" ||
                v == "OUTSIDE_OFFICER" ||
                v == "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER" ||
                (v == "GUEST" && showWorkFieldsForGuest));

            if (!shouldShowWork) {
              ministryController.clear();
              departmentController.clear();
              officeController.clear();
              positionController.clear();
            }

            if (v != "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER") {
              provinceCityController.clear();
            }

            // duration types: NATIONAL + GUEST
            if (v == "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER" || v == "GUEST") {
              requestDateController.clear();
            } else {
              durationDaysController.clear();
            }

            // reset attachments
            attachFiles.clear();
            attachFileNames.clear();
            attachFilesError = null;

            cameraFile = null;
            cameraFileName = null;
            cameraError = null;

            // reset dropdown selections/controllers
            _resetWorkDropdownStateAndControllers();
          });

          // ✅ load dropdown data only for OFFICERS
          await _loadWorkDropdownsIfNeeded();
        },
      ),
    );
  }

  Widget Rowlabel() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text("លេខទូរស័ព្ទ"),
          Spacer(),
          Text("កាលបរិច្ឆេទស្នើរ"),
        ],
      ),
    );
  }

  Widget phoneAndDate() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: inputDecoration("លេខទូរស័ព្ទ"),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: requestDateController,
              readOnly: true,
              decoration: inputDecoration("ថ្ងៃស្នើរ").copyWith(
                suffixIcon: const Icon(Icons.calendar_month),
              ),
              onTap: pickDate,
            ),
          ),
        ],
      ),
    );
  }

  Widget oneInput({
    required String label,
    required String hint,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          TextFormField(
              controller: controller, decoration: inputDecoration(hint)),
        ],
      ),
    );
  }

  Widget twoInputRow(
    String lLabel,
    String rLabel,
    String lHint,
    String rHint,
    TextEditingController lCtrl,
    TextEditingController rCtrl, {
    required bool leftIsPlate,
    required bool rightIsPlate,
  }) {
    final isLeftId = lCtrl == idNumberController;
    final isRightId = rCtrl == idNumberController;

    const plateMaxLen = 18;

    List<TextInputFormatter>? formatters(bool isId, bool isPlate) {
      if (isId) {
        return <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ];
      }
      if (isPlate) {
        return <TextInputFormatter>[
          LengthLimitingTextInputFormatter(plateMaxLen),
          TextInputFormatter.withFunction((oldValue, newValue) {
            final up = newValue.text.toUpperCase();
            return newValue.copyWith(text: up, selection: newValue.selection);
          }),
        ];
      }
      return null;
    }

    int? maxLen(bool isId, bool isPlate) {
      if (isId) return 10;
      if (isPlate) return plateMaxLen;
      return null;
    }

    TextCapitalization cap(bool isPlate) =>
        isPlate ? TextCapitalization.characters : TextCapitalization.none;

    TextInputType kbd(bool isId) => isId ? TextInputType.number : TextInputType.text;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(lLabel),
              const Spacer(),
              Text(rLabel),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: lCtrl,
                  decoration: inputDecoration(lHint),
                  keyboardType: kbd(isLeftId),
                  textCapitalization: cap(leftIsPlate),
                  maxLength: maxLen(isLeftId, leftIsPlate),
                  buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  inputFormatters: formatters(isLeftId, leftIsPlate),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: rCtrl,
                  decoration: inputDecoration(rHint),
                  keyboardType: kbd(isRightId),
                  textCapitalization: cap(rightIsPlate),
                  maxLength: maxLen(isRightId, rightIsPlate),
                  buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  inputFormatters: formatters(isRightId, rightIsPlate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget bottom() {
    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xffDFB73B)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () {
                    setState(() => vehicles.add(_VehicleForm()));
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add, color: Color(0xffDFB73B), size: 20),
                      SizedBox(width: 6),
                      Text(
                        "បន្ថែមរថយន្ត",
                        style:
                            TextStyle(fontSize: 16, color: Color(0xffDFB73B)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffDFB73B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: submitRegister,
                  child: const Text(
                    "ដាក់ស្នើ",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    );
  }
}
