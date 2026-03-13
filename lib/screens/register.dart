import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gov_reg/models/parking_card.dart';
import 'package:gov_reg/routes/approute.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class _VehicleForm {
  final brand = TextEditingController();
  final plate = TextEditingController();
  final color = TextEditingController();
  final year = TextEditingController();

  String vehicleType = "CAR";
  String carPlateType = "REGULAR";
  String motoPlateType = "REGULAR";

  String? carPlateSubcategory;
  String? carPlateSubcategoryCode;
  String? motoPlateSubcategory;
  String? motoPlateSubcategoryCode;

  List<PlateSubCategoryItem> carSubcategories = [];
  List<PlateSubCategoryItem> motoSubcategories = [];

  void dispose() {
    brand.dispose();
    plate.dispose();
    color.dispose();
    year.dispose();
  }
}

class PlateSubCategoryItem {
  final String code;
  final String name;
  final String category;

  PlateSubCategoryItem({
    required this.code,
    required this.name,
    required this.category,
  });

  factory PlateSubCategoryItem.fromJson(Map<String, dynamic> json) {
    return PlateSubCategoryItem(
      code: (json['code'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      category: (json['category'] ?? json['plateCategory'] ?? '') as String,
    );
  }
}

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
  DepartmentItem(
      {required this.id,
      required this.name,
      required this.generalDepartmentId});
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
  BurauItem({required this.id, required this.name, required this.departmentId});
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
    "SECRETARY",
    "DEPUTY_SECRETARY",
    "INSIDE_OFFICER",
    "OUTSIDE_OFFICER",
    "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER",
    "GUEST",
  ];

  static const String attachmentTypeVehicle = "VEHICLE_DOCUMENT";
  static const String attachmentTypeSelfie = "INVITATION_DOCUMENT";

  String _userType = "GUEST";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWorkDropdownsIfNeeded(userTypeOverride: _userType);
    _initDefaultSubcategories();
  }

  Future<void> _initDefaultSubcategories() async {
    final carSubs = await fetchPlateSubCategories("REGULAR");
    final motoSubs = await fetchPlateSubCategories("REGULAR");
    if (!mounted) return;
    setState(() {
      vehicles.first.carSubcategories = carSubs;
      vehicles.first.motoSubcategories = motoSubs;
    });
  }

  static const int maxFiles = 5;
  final List<File> attachFiles = [];
  final List<String> attachFileNames = [];
  String? attachFilesError;

  File? cameraFile;
  String? cameraFileName;
  String? cameraError;
  final ImagePicker _imagePicker = ImagePicker();

  final fullNameController = TextEditingController();
  final idNumberController = TextEditingController();
  final ministryController = TextEditingController();
  final departmentController = TextEditingController();
  final officeController = TextEditingController();
  final positionController = TextEditingController();
  final phoneController = TextEditingController();
  final searchController = TextEditingController();
  final requestDateController = TextEditingController();
  final provinceCityController = TextEditingController();
  final reasonController = TextEditingController();
  final durationDaysController = TextEditingController();

  int? selectedDurationDays;
  String? durationError;

  final List<_VehicleForm> vehicles = [_VehicleForm()];

  int _lastRequestDateInt = 0;
  String? _lastRequestAtDateStr;

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

  void _syncWorkControllersFromDropdownIfNeeded() {
    if (!useWorkDropdown) return;
    if (selectedGD != null) ministryController.text = selectedGD!.name;
    if (selectedDept != null) departmentController.text = selectedDept!.name;
    if (selectedBurau != null) officeController.text = selectedBurau!.name;
    if (selectedPos != null) positionController.text = selectedPos!.name;
  }

  final List<Map<String, dynamic>> plateCategory = [
    {"key": "ROYAL_PALACE", "label": "រាជវាំង"},
    {"key": "STATE", "label": "រដ្ឋ"},
    {"key": "POLICE", "label": "នគរបាល"},
    {"key": "ARMY_FORCE", "label": "ខេមរភូមិន្ទ"},
    {"key": "ORGANIZATION", "label": "អង្គការ"},
    {"key": "EMBASSY", "label": "អង្គទូត"},
    {"key": "UNITED_NATIONS", "label": "អង្គការសហប្រជាជាតិ"},
    {"key": "TEMPORARY", "label": "បណ្តោះអាសន្ន"},
    {"key": "REGULAR", "label": "ធម្មតា"},
    {"key": "CAMBODIA", "label": "កម្ពុជា"},
  ];

  final List<Map<String, dynamic>> motoPlateTypes = [
    {"key": "REGULAR", "label": "ធម្មតា"},
    {"key": "CAMBODIA", "label": "កម្ពុជា"},
    {"key": "POLICE", "label": "នគរបាល"},
    {"key": "ARMY_FORCE", "label": "ខេមរភូមិន្ទ"},
  ];

  String getPlateKey(_VehicleForm v) {
    return v.vehicleType == "MOTORBIKE" ? v.motoPlateType : v.carPlateType;
  }

  String? getSubcategoryKey(_VehicleForm v) {
    final code = v.vehicleType == "MOTORBIKE"
        ? v.motoPlateSubcategory // ← was motoPlateSubcategoryCode
        : v.carPlateSubcategory; // ← was carPlateSubcategoryCode
    return (code != null && code.trim().isNotEmpty) ? code : null;
  }

  bool get isGuest => _userType == "GUEST";
  bool get isInsideOfficer => _userType == "INSIDE_OFFICER";
  bool get isOutsideOfficer => _userType == "OUTSIDE_OFFICER";
  bool get isOfficer => isInsideOfficer || isOutsideOfficer;
  bool get isNational =>
      _userType == "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER";

  static const bool showWorkFieldsForGuest = true;

  bool get showIdNumber => isOfficer;
  bool get showWorkFields =>
      isOfficer || isNational || (isGuest && showWorkFieldsForGuest);
  bool get showProvinceCity => isNational;
  bool get useDurationDays => isNational || isGuest;
  bool get selfieRequired => isGuest;
  bool get useWorkDropdown => isOfficer;

  String _normalizePlate(String s) =>
      s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int _fmtYmdInt(DateTime d) => int.parse(
      "${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}");

  String _fmtDmy(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";

  static final Map<String, List<RegExp>> _categoryRules = {
    "ROYAL_PALACE": [RegExp(r'^[0-9]{3}$')],
    "STATE": [RegExp(r'^[2-6]{1}-[0-9]{3,4}$')],
    "POLICE": [RegExp(r'^[2-6]{1}-[0-9]{4}$')],
    "ARMY_FORCE": [RegExp(r'^[2-6]{1}-[0-9]{4}$')],
    "REGULAR": [RegExp(r'^[2-6]{1}[A-Z]{1,2}-[0-9]{4}$')],
    "CAMBODIA": [RegExp(r'^[A-Z0-9.]{8,}$')],
    "MOTORBIKE_REGULAR": [RegExp(r'^1[A-Z]{1,2}-[0-9]{4}$')],
    "MOTORBIKE_CAMBODIA": [RegExp(r'^[A-Z0-9.]{8,}$')],
    "MOTORBIKE_POLICE": [RegExp(r'^1-[0-9]{4}$')],
    "MOTORBIKE_ARMY_FORCE": [RegExp(r'^1-[0-9]{4}$')],
  };

  String _ruleKeyForVehicle(_VehicleForm v) {
    if (v.vehicleType != "MOTORBIKE") return v.carPlateType;
    switch (v.motoPlateType) {
      case "REGULAR":
        return "MOTORBIKE_REGULAR";
      case "CAMBODIA":
        return "MOTORBIKE_CAMBODIA";
      case "POLICE":
        return "MOTORBIKE_POLICE";
      case "ARMY_FORCE":
        return "MOTORBIKE_ARMY_FORCE";
      default:
        return "MOTORBIKE_REGULAR";
    }
  }

  bool _validatePlate(_VehicleForm v, String plate) {
    final rules = _categoryRules[_ruleKeyForVehicle(v)];
    if (rules == null) return true;
    return rules.any((r) => r.hasMatch(_normalizePlate(plate)));
  }

  String _formatPlateLive(_VehicleForm v, String raw) {
    final ruleKey = _ruleKeyForVehicle(v);
    final upper = raw.toUpperCase();

    if (ruleKey.contains("CAMBODIA"))
      return upper.replaceAll(RegExp(r'[^A-Z0-9.]'), '');

    var cleaned =
        upper.replaceAll(RegExp(r'[^A-Z0-9-]'), '').replaceAll('-', '');

    final isGov = [
      "STATE",
      "POLICE",
      "ARMY_FORCE",
      "MOTORBIKE_POLICE",
      "MOTORBIKE_ARMY_FORCE"
    ].contains(ruleKey);
    if (isGov) {
      if (cleaned.length <= 1) return cleaned;
      return '${cleaned.substring(0, 1)}-${cleaned.substring(1)}';
    }

    if (cleaned.isEmpty) return '';
    final first = cleaned.substring(0, 1);
    final rest = cleaned.substring(1);
    final letters = RegExp(r'^[A-Z]{0,2}').stringMatch(rest) ?? '';
    final nums =
        rest.substring(letters.length).replaceAll(RegExp(r'[^0-9]'), '');

    if (letters.isNotEmpty && nums.isNotEmpty) return '$first$letters-$nums';
    return '$first$letters$nums';
  }

  List<TextInputFormatter> _plateFormatters(_VehicleForm v) {
    final ruleKey = _ruleKeyForVehicle(v);
    return [
      FilteringTextInputFormatter.allow(
        ruleKey.contains("CAMBODIA")
            ? RegExp(r'[0-9A-Za-z.]')
            : RegExp(r'[0-9A-Za-z-]'),
      ),
      LengthLimitingTextInputFormatter(ruleKey.contains("CAMBODIA") ? 20 : 12),
      TextInputFormatter.withFunction((oldValue, newValue) {
        final formatted = _formatPlateLive(v, newValue.text);
        return TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length));
      }),
    ];
  }

  Future<http.Response> _get(Uri uri) async {
    return http.get(uri, headers: {"Accept": "application/json"});
  }

  // ----------------------------
  // ✅ Search — typed, handles list or single
  // ----------------------------
  Future<void> _search({required String search}) async {
    final uri =
        Uri.parse("$baseUrl/api/v1/parking-card-requests/search/$search");
    try {
      final res = await _get(uri);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);

        List<ParkingCardRequestResponseDTO> results = [];
        if (body is List) {
          results = body
              .map((e) => ParkingCardRequestResponseDTO.fromJson(
                  e as Map<String, dynamic>))
              .toList();
        } else if (body is Map<String, dynamic>) {
          results = [ParkingCardRequestResponseDTO.fromJson(body)];
        }

        if (results.isEmpty) {
          _snack("រកមិនឃើញទិន្នន័យ (Request not found)");
          return;
        }

        _snack("ស្វែងរកជោគជ័យ (Search Successful)");
        if (!mounted) return;

        Navigator.pushNamed(
          context,
          Approute.verifySuccessScreen,
          arguments: {
            "response": results.first,
            "allResults":
                results, // ✅ pass full list — success screen can paginate
            "selfieBytes": null,
            "selfiePath": null,
          },
        );
      } else if (res.statusCode == 404 || res.body.contains("not found")) {
        _snack("រកមិនឃើញទិន្នន័យ (Request not found)");
      } else if (res.statusCode == 403) {
        _snack("403 Forbidden (No permission)");
      } else if (res.statusCode == 500) {
        _snack("កំហុសម៉ាស៊ីនបម្រើ (Server Error: 500)");
      } else {
        _snack("មានបញ្ហាអ្វីមួយ (Error: ${res.statusCode})");
      }
      debugPrint("Search Response Body: ${res.body}");
    } catch (e) {
      _snack("(Connection Error)");
    }
  }

  Future<List<GeneralDepartmentItem>> fetchGeneralDepartments() async {
    final res = await _get(Uri.parse("$baseUrl/api/v1/general-departments"));
    if (res.statusCode != 200)
      throw "GeneralDepartments HTTP ${res.statusCode}";
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .map((e) => GeneralDepartmentItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DepartmentItem>> fetchDepartmentsByGeneralDepartment(
      int gdId) async {
    final res = await _get(
        Uri.parse("$baseUrl/api/v1/departments/general-department/$gdId"));
    if (res.statusCode != 200) throw "Departments HTTP ${res.statusCode}";
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .map((e) => DepartmentItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BurauItem>> fetchBuraus() async {
    final res = await _get(Uri.parse("$baseUrl/api/v1/bureaus"));
    if (res.statusCode != 200) throw "Buraus HTTP ${res.statusCode}";
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .map((e) => BurauItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PositionItem>> fetchPositions() async {
    final res = await _get(Uri.parse("$baseUrl/api/v1/positions"));
    if (res.statusCode != 200) throw "Positions HTTP ${res.statusCode}";
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .map((e) => PositionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PlateSubCategoryItem>> fetchPlateSubCategories(
      String category) async {
    final res = await _get(Uri.parse(
        "$baseUrl/api/v1/platenumber-sub-categories/category/$category"));
    if (res.statusCode != 200) return [];
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .map((e) => PlateSubCategoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _loadWorkDropdownsIfNeeded({String? userTypeOverride}) async {
    final type = userTypeOverride ?? _userType;
    if (type != "INSIDE_OFFICER" && type != "OUTSIDE_OFFICER") return;

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
      burauFiltered =
          burauAll.where((b) => b.departmentId == (d?.id ?? -1)).toList();
    });
  }

  void onSelectBurau(BurauItem? b) => setState(() {
        selectedBurau = b;
        officeController.text = b?.name ?? "";
      });
  void onSelectPosition(PositionItem? p) => setState(() {
        selectedPos = p;
        positionController.text = p?.name ?? "";
      });

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
      if (await file.length() > 5 * 1024 * 1024) {
        setState(() => attachFilesError = "ឯកសារត្រូវ ≤ 5MB");
        return;
      }
      if (!['png', 'jpg', 'jpeg', 'pdf']
          .contains((f.extension ?? "").toLowerCase())) {
        setState(() => attachFilesError = "ប្រភេទឯកសារមិនត្រឹមត្រូវ");
        return;
      }
      if (attachFiles.any((x) => x.path == file.path)) continue;
      attachFiles.add(file);
      attachFileNames.add(f.name);
    }
    setState(() {});
  }

  void removeAttachFileAt(int i) => setState(() {
        attachFiles.removeAt(i);
        attachFileNames.removeAt(i);
      });

  Future<void> pickCameraImage() async {
    setState(() => cameraError = null);
    final XFile? xfile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2000,
        maxHeight: 2000);
    if (xfile == null) return;

    File file = File(xfile.path);
    int bytes = await file.length();
    if (bytes > 5 * 1024 * 1024) {
      setState(() => cameraError = "រូបភាពត្រូវ ≤ 5MB");
      return;
    }

    if (bytes < 153600) {
      img.Image? decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) {
        setState(() => cameraError = "មិនអាចដំណើរការរូបភាពបាន");
        return;
      }
      int attempt = 0;
      while (bytes < 153600 && attempt < 5) {
        decoded = img.copyResize(decoded!,
            width: (decoded.width * 1.1).toInt(),
            height: (decoded.height * 1.1).toInt());
        await file.writeAsBytes(img.encodeJpg(decoded, quality: 100));
        bytes = await file.length();
        attempt++;
      }
      if (bytes < 153600) {
        setState(() => cameraError = "រូបភាពត្រូវមានទំហំ ≥ 150KB");
        return;
      }
    }

    setState(() {
      cameraFile = file;
      cameraFileName = xfile.name;
      cameraError = null;
    });
  }

  void clearCamera() => setState(() {
        cameraFile = null;
        cameraFileName = null;
        cameraError = null;
      });

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

  bool validateForm() {
    setState(() => durationError = null);
    if (fullNameController.text.trim().isEmpty) {
      _snack("សូមបញ្ចូលឈ្មោះពេញ");
      return false;
    }
    if (showIdNumber) {
      final id = idNumberController.text.trim();
      if (id.isEmpty) {
        _snack("សូមបញ្ចូលអត្តលេខ");
        return false;
      }
      if (!RegExp(r'^\d+$').hasMatch(id)) {
        _snack("អត្តលេខត្រូវមានតែលេខ");
        return false;
      }
      if (id.length > 10) {
        _snack("អត្តលេខមិនអាចលើស ១០ ខ្ទង់បានទេ");
        return false;
      }
    }
    if (phoneController.text.trim().isEmpty) {
      _snack("សូមបញ្ចូលលេខទូរស័ព្ទ");
      return false;
    }
    if (useDurationDays &&
        (selectedDurationDays == null ||
            selectedDurationDays! < 1 ||
            selectedDurationDays! > 7)) {
      setState(() => durationError = "សូមជ្រើសរយៈពេល ១-៧ ថ្ងៃ");
      _snack("សូមជ្រើសរយៈពេល ១-៧ ថ្ងៃ");
      return false;
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
      if (v.color.text.trim().isEmpty) {
        _snack("សូមបញ្ចូលពណ៌ (#${i + 1})");
        return false;
      }
      final year = int.tryParse(v.year.text.trim());
      if (year == null || year < 1900) {
        _snack("ឆ្នាំផលិតមិនត្រឹមត្រូវ (#${i + 1})");
        return false;
      }
      if (v.plate.text.trim().isEmpty) {
        _snack("សូមបញ្ចូលផ្លាកលេខ (#${i + 1})");
        return false;
      }
      if (!_validatePlate(v, v.plate.text)) {
        _snack("ផ្លាកលេខមិនត្រឹមត្រូវ (#${i + 1})");
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
  // ✅ Returns typed ParkingCardRequestResponseDTO
  // ----------------------------
  Future<ParkingCardRequestResponseDTO> createParkingCardRequest() async {
    _syncWorkControllersFromDropdownIfNeeded();

    final attachmentTypes = [
      ...List.filled(attachFiles.length, attachmentTypeVehicle),
      if (cameraFile != null) attachmentTypeSelfie,
    ];

    final queryString = attachmentTypes.isEmpty
        ? ""
        : "?${attachmentTypes.map((e) => "attachmentTypes=${Uri.encodeQueryComponent(e)}").join("&")}";

    final uri = Uri.parse("$baseUrl/api/v1/parking-card-requests$queryString");

    final now = DateTime.now();
    final requestAt = now;
    final requestEnd = useDurationDays
        ? requestAt.add(Duration(days: selectedDurationDays ?? 1))
        : DateTime(now.year + 1, now.month, now.day);

    _lastRequestDateInt = _fmtYmdInt(requestEnd);
    _lastRequestAtDateStr = _fmtDmy(requestAt);

    String _fill(String s) => s.isEmpty ? "-" : s;

    final gdText = showWorkFields ? _fill(ministryController.text.trim()) : "";
    final deptText =
        showWorkFields ? _fill(departmentController.text.trim()) : "";
    final bureauText =
        showWorkFields ? _fill(officeController.text.trim()) : "";
    final posText = showWorkFields ? _fill(positionController.text.trim()) : "";

    // ✅ Build typed request DTO
    final requestDto = ParkingCardRequestRequestDTO(
      reason: reasonController.text.trim().isEmpty
          ? "Parking card request"
          : reasonController.text.trim(),
      requestDate: _lastRequestDateInt,
      requestAtDate: _userType != "GUEST" ? _lastRequestAtDateStr : null,
      user: UserRequestDTO(
        name: fullNameController.text.trim(),
        phone: phoneController.text.trim(),
        userType: UserTypeX.fromString(_userType),
      ),
      workingInfo: WorkingInfoDTO(
        policeId: showIdNumber ? idNumberController.text.trim() : "",
        generalDepartmentText: gdText,
        departmentText: deptText,
        bureauText: bureauText,
        positionText: posText,
        generalDepartment: useWorkDropdown ? (selectedGD?.id ?? 0) : 0,
        department: useWorkDropdown ? (selectedDept?.id ?? 0) : 0,
        bureau: useWorkDropdown ? (selectedBurau?.id ?? 0) : 0,
        position: useWorkDropdown ? (selectedPos?.id ?? 0) : 0,
        provinceCity:
            showProvinceCity ? provinceCityController.text.trim() : "",
      ),
      vehicles: vehicles
          .map((v) => VehicleDTO(
                brand: v.brand.text.trim(),
                color: v.color.text.trim(),
                madeYear: int.tryParse(v.year.text.trim()) ?? 0,
                vehicleType: v.vehicleType,
                plate: PlateNumberDTO(
                  plateNumber: _normalizePlate(v.plate.text),
                  plateCategory: v.vehicleType == "MOTORBIKE"
                      ? v.motoPlateType
                      : v.carPlateType,
                  plateSubCategory: getSubcategoryKey(v),
                ),
              ))
          .toList(),
    );

    debugPrint("URI = $uri");
    debugPrint("DTO SENT = ${jsonEncode(requestDto.toJson())}");

    final request = http.MultipartRequest("POST", uri);
    request.headers["Accept"] = "application/json";
    request.files.add(http.MultipartFile.fromString(
      "dto",
      jsonEncode(requestDto.toJson()),
      filename: "dto.json",
      contentType: MediaType("application", "json"),
    ));

    for (int i = 0; i < attachFiles.length; i++) {
      request.files.add(await http.MultipartFile.fromPath(
          "files", attachFiles[i].path,
          filename: attachFileNames[i]));
    }
    if (cameraFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
          "files", cameraFile!.path,
          filename: cameraFileName ?? cameraFile!.path.split("/").last));
    }

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    debugPrint("STATUS: ${resp.statusCode}");
    debugPrint("BODY: ${resp.body}");

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception("HTTP ${resp.statusCode}: ${resp.body}");
    }

    if (resp.body.isEmpty) return ParkingCardRequestResponseDTO();
    final decoded = jsonDecode(resp.body);
    return ParkingCardRequestResponseDTO.fromJson(
        decoded is Map<String, dynamic> ? decoded : {});
  }

  // ----------------------------
  // ✅ submitRegister — typed end-to-end
  // ----------------------------
  Future<void> submitRegister() async {
    debugPrint("SUBMIT pressed");
    _syncWorkControllersFromDropdownIfNeeded();
    if (!validateForm()) return;
    setState(() => isLoading = true);

    try {
      final ParkingCardRequestResponseDTO res =
          await createParkingCardRequest();
      if (!mounted) return;

      Uint8List? selfieBytes;
      if (cameraFile != null) selfieBytes = await cameraFile!.readAsBytes();

      // ✅ Merge local fallbacks for fields the API might not echo back
      final filledRes = ParkingCardRequestResponseDTO(
        id: res.id,
        name: res.name ?? fullNameController.text.trim(),
        code: res.code,
        token: res.token,
        userType: res.userType ?? UserTypeX.fromString(_userType),
        organization: res.organization,
        position: res.position,
        policeId: res.policeId ?? idNumberController.text.trim(),
        department: res.department,
        bureau: res.bureau,
        phone: res.phone ?? phoneController.text.trim(),
        vehicles: res.vehicles,
        attachments: res.attachments,
        requestDate: res.requestDate ?? _lastRequestDateInt,
        requestAtDate: res.requestAtDate ?? _lastRequestAtDateStr,
        parkingRequestStatus: res.parkingRequestStatus,
        positionText: res.positionText ?? positionController.text.trim(),
        generalDepartment: res.generalDepartment,
        generalDepartmentText:
            res.generalDepartmentText ?? ministryController.text.trim(),
        departmentText: res.departmentText ?? departmentController.text.trim(),
        bureauText: res.bureauText ?? officeController.text.trim(),
        reason: res.reason,
        provinceCity: res.provinceCity ?? provinceCityController.text.trim(),
        createdAt: res.createdAt,
      );

      Navigator.pushNamed(
        context,
        Approute.verifySuccessScreen,
        arguments: {
          "response": filledRes, // ✅ typed model
          "allResults": [filledRes], // ✅ list of 1 for submit case
          "selfieBytes": selfieBytes,
          "selfiePath": cameraFile?.path,
        },
      );
    } catch (e) {
      debugPrint("SUBMIT ERROR: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ----------------------------
  // UI
  // ----------------------------
  Widget fieldBlock({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        child,
      ]),
    );
  }

  Widget textFieldBlock({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return fieldBlock(
      label: label,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        buildCounter: (context,
                {required currentLength, required isFocused, maxLength}) =>
            null,
        decoration: inputDecoration(hint).copyWith(suffixIcon: suffixIcon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!allowedUserTypes.contains(_userType)) _userType = "GUEST";

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(children: [
          _header(),
          Transform.translate(
            offset: const Offset(0, -60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(
                        blurRadius: 12,
                        offset: Offset(0, 6),
                        color: Colors.black12)
                  ],
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(children: [
                          Expanded(
                              child: TextFormField(
                            controller: searchController,
                            decoration:
                                inputDecoration("តាមរយះ លេខកូដ ឬលេខទូរស័ព្ទ")
                                    .copyWith(
                                        prefixIcon: const Icon(Icons.search)),
                          )),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 48,
                            width: 48,
                            child: ElevatedButton(
                              onPressed: () =>
                                  _search(search: searchController.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                side: BorderSide(color: Colors.grey.shade400),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                                padding: EdgeInsets.zero,
                              ),
                              child: const Icon(Icons.search,
                                  size: 24, color: Colors.black),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      sectionTitle("ព័ត៌មានផ្ទាល់ខ្លួន"),
                      dropdownUserType(),
                      const SizedBox(height: 15),
                      oneInput(
                          label: "គោត្តនាម និងនាម",
                          hint: "បញ្ចូលឈ្មោះពេញ",
                          controller: fullNameController),
                      if (showIdNumber)
                        textFieldBlock(
                          label: "អត្តលេខ",
                          hint: "បញ្ចូលអត្តលេខ",
                          controller: idNumberController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10)
                          ],
                          maxLength: 10,
                        ),
                      if (showWorkFields) ...[
                        sectionTitle("ព័ត៌មានការងារ"),
                        if (useWorkDropdown) ...[
                          if (dropdownLoading)
                            const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                child: LinearProgressIndicator()),
                          _ddGeneralDepartment(),
                          _ddDepartment(),
                          _ddBurau(),
                          _ddPosition(),
                        ] else ...[
                          oneInput(
                              label: "ក្រសួង/ស្ថាប័ន",
                              hint: "បញ្ចូលក្រសួង",
                              controller: ministryController),
                          oneInput(
                              label: "នាយកដ្ឋាន/អង្គភាព",
                              hint: "បញ្ចូលនាយកដ្ឋាន",
                              controller: departmentController),
                          oneInput(
                              label: "ការិយាល័យ",
                              hint: "បញ្ចូលការិយាល័យ",
                              controller: officeController),
                          oneInput(
                              label: "តួនាទី",
                              hint: "បញ្ចូលតួនាទី",
                              controller: positionController),
                        ],
                      ],
                      if (showProvinceCity)
                        oneInput(
                            label: "ខេត្ត/រាជធានី",
                            hint: "បញ្ចូលខេត្ត/រាជធានី",
                            controller: provinceCityController),
                      textFieldBlock(
                          label: "លេខទូរស័ព្ទ",
                          hint: "លេខទូរស័ព្ទ",
                          controller: phoneController,
                          keyboardType: TextInputType.phone),
                      if (useDurationDays) ...[
                        fieldBlock(
                          label: "រយៈពេលស្នើរ (១-៧ ថ្ងៃ)",
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: selectedDurationDays,
                            decoration: inputDecoration("ជ្រើសរយៈពេល ១-៧ ថ្ងៃ")
                                .copyWith(errorText: durationError),
                            items: List.generate(
                                7,
                                (i) => DropdownMenuItem<int>(
                                    value: i + 1,
                                    child: Text("${i + 1} ថ្ងៃ"))),
                            onChanged: (v) => setState(() {
                              selectedDurationDays = v;
                              durationError = null;
                            }),
                          ),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 6),
                          child: Text(
                              "កាលបរិច្ឆេទស្នើរ៖ ស្វ័យប្រវត្តិ (ថ្ងៃនេះ) | ផុតកំណត់៖ ១ ឆ្នាំ",
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700)),
                        ),
                      ],
                      sectionTitle("ព័ត៌មានរថយន្ត/ម៉ូតូ"),
                      ...List.generate(vehicles.length, (i) {
                        final v = vehicles[i];
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 6),
                                child: Row(children: [
                                  Text("រថយន្ត/ម៉ូតូ #${i + 1}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  if (vehicles.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => setState(() {
                                        v.dispose();
                                        vehicles.removeAt(i);
                                      }),
                                    ),
                                ]),
                              ),
                              Row(children: [
                                Expanded(
                                    child: RadioListTile<String>(
                                  value: "CAR",
                                  groupValue: v.vehicleType,
                                  title: const Text("រថយន្ត"),
                                  onChanged: (x) async {
                                    setState(() => v.vehicleType = x!);
                                    if (v.carSubcategories.isEmpty) {
                                      final subs =
                                          await fetchPlateSubCategories(
                                              v.carPlateType);
                                      if (!mounted) return;
                                      setState(() => v.carSubcategories = subs);
                                    }
                                  },
                                )),
                                Expanded(
                                    child: RadioListTile<String>(
                                  value: "MOTORBIKE",
                                  groupValue: v.vehicleType,
                                  title: const Text("ម៉ូតូ"),
                                  onChanged: (x) async {
                                    setState(() => v.vehicleType = x!);
                                    if (v.motoSubcategories.isEmpty) {
                                      final subs =
                                          await fetchPlateSubCategories(
                                              v.motoPlateType);
                                      if (!mounted) return;
                                      setState(
                                          () => v.motoSubcategories = subs);
                                    }
                                  },
                                )),
                              ]),
                              oneInput(
                                  label: "ម៉ាក",
                                  hint: "បញ្ចូលម៉ាក",
                                  controller: v.brand),
                              plateRow(v),
                              textFieldBlock(
                                  label: "ផ្លាកលេខ",
                                  hint: "សូមបញ្ចូលផ្លាកលេខ",
                                  controller: v.plate,
                                  inputFormatters: _plateFormatters(v)),
                              const SizedBox(height: 10),
                              Center(
                                  child: plateBox(
                                label: () {
                                  final isMoto = v.vehicleType == "MOTORBIKE";
                                  final code = isMoto
                                      ? v.motoPlateSubcategory
                                      : v.carPlateSubcategory;
                                  final subs = isMoto
                                      ? v.motoSubcategories
                                      : v.carSubcategories;
                                  if (code == null) return "";
                                  try {
                                    return subs
                                        .firstWhere((s) => s.code == code)
                                        .name;
                                  } catch (_) {
                                    return code;
                                  }
                                }(),
                                code: _normalizePlate(v.plate.text).isEmpty
                                    ? "----"
                                    : _normalizePlate(v.plate.text),
                                keyText: getPlateKey(v),
                              )),
                              oneInput(
                                  label: "ពណ៌",
                                  hint: "ពណ៌រថយន្ត",
                                  controller: v.color),
                              oneInput(
                                  label: "ឆ្នាំផលិត",
                                  hint: "ឆ្នាំផលិត",
                                  controller: v.year),
                              const Divider(height: 24),
                            ]);
                      }),
                      uploadMultiAttachment(),
                      uploadCameraAttachment(),
                      bottom(),
                      const SizedBox(height: 30),
                    ]),
              ),
            ),
          ),
          const SizedBox(height: 60),
        ]),
      ),
    );
  }

  Widget _ddGeneralDepartment() => fieldBlock(
      label: "ក្រសួង/ស្ថាប័ន",
      child: DropdownButtonFormField<GeneralDepartmentItem>(
        isExpanded: true,
        value: selectedGD,
        decoration: inputDecoration("ជ្រើសក្រសួង/ស្ថាប័ន"),
        items: gdList
            .map((x) => DropdownMenuItem(
                value: x, child: Text(x.name, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (x) => onSelectGD(x),
      ));

  Widget _ddDepartment() => fieldBlock(
      label: "នាយកដ្ឋាន/អង្គភាព",
      child: DropdownButtonFormField<DepartmentItem>(
        isExpanded: true,
        value: selectedDept,
        decoration: inputDecoration("ជ្រើសនាយកដ្ឋាន/អង្គភាព"),
        items: deptList
            .map((x) => DropdownMenuItem(
                value: x, child: Text(x.name, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (x) => onSelectDept(x),
      ));

  Widget _ddBurau() => fieldBlock(
      label: "ការិយាល័យ",
      child: DropdownButtonFormField<BurauItem>(
        isExpanded: true,
        value: selectedBurau,
        decoration: inputDecoration("ជ្រើសការិយាល័យ"),
        items: burauFiltered
            .map((x) => DropdownMenuItem(
                value: x, child: Text(x.name, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (x) => onSelectBurau(x),
      ));

  Widget _ddPosition() => fieldBlock(
      label: "តួនាទី",
      child: DropdownButtonFormField<PositionItem>(
        isExpanded: true,
        value: selectedPos,
        decoration: inputDecoration("ជ្រើសតួនាទី"),
        items: posList
            .map((x) => DropdownMenuItem(
                value: x, child: Text(x.name, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (x) => onSelectPosition(x),
      ));

  Widget oneInput(
          {required String label,
          required String hint,
          required TextEditingController controller}) =>
      textFieldBlock(label: label, hint: hint, controller: controller);

  Widget plateRow(_VehicleForm v) {
    final isMoto = v.vehicleType == "MOTORBIKE";
    final currentType = isMoto ? v.motoPlateType : v.carPlateType;
    final currentSubcategoryCode =
        isMoto ? v.motoPlateSubcategory : v.carPlateSubcategory;
    final subcategories = isMoto ? v.motoSubcategories : v.carSubcategories;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Plate type dropdown ──────────────────────────────────────
      fieldBlock(
        label: isMoto ? "ប្រភេទស្លាកលេខម៉ូតូ" : "ប្រភេទស្លាកលេខរថយន្ត",
        child: DropdownButtonFormField<String>(
          isExpanded: true,
          value: currentType,
          decoration: inputDecoration("ប្រភេទស្លាក"),
          items: (isMoto ? motoPlateTypes : plateCategory)
              .map((t) => DropdownMenuItem<String>(
                    value: t["key"],
                    child: Text(t["label"]!,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (x) async {
            if (x == null) return;
            setState(() {
              if (isMoto) {
                v.motoPlateType = x;
                v.motoPlateSubcategory = null;
                v.motoSubcategories = [];
              } else {
                v.carPlateType = x;
                v.carPlateSubcategory = null;
                v.carSubcategories = [];
              }
              v.plate.text = _formatPlateLive(v, v.plate.text);
            });
            final subs = await fetchPlateSubCategories(x);
            if (!mounted) return;
            setState(() {
              if (isMoto)
                v.motoSubcategories = subs;
              else
                v.carSubcategories = subs;
            });
          },
        ),
      ),

      // ── Subcategory dropdown ─────────────────────────────────────
      fieldBlock(
        label: "ក្រុមផ្លាកលេខ",
        child: subcategories.isEmpty
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text("កំពុងដំណើរការ...",
                    style: TextStyle(color: Colors.grey)),
              )
            : DropdownButtonFormField<String>(
                isExpanded: true,
                // ✅ match by code, not name
                value: (currentSubcategoryCode != null &&
                        subcategories
                            .any((s) => s.code == currentSubcategoryCode))
                    ? currentSubcategoryCode
                    : null,
                decoration: inputDecoration("ជ្រើសក្រុមផ្លាកលេខ"),
                // ✅ value = code, display = Khmer name
                items: subcategories
                    .map((sub) => DropdownMenuItem<String>(
                          value: sub.code,
                          child: Text(sub.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (selectedCode) {
                  if (selectedCode == null) return;
                  setState(() {
                    // ✅ store code — this is what gets posted
                    if (isMoto)
                      v.motoPlateSubcategory = selectedCode;
                    else
                      v.carPlateSubcategory = selectedCode;
                  });
                },
              ),
      ),
    ]);
  }

  Widget plateBox(
      {required String label, required String code, required String keyText}) {
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: Colors.blue, width: 2),
          borderRadius: BorderRadius.circular(8)),
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w500, color: Colors.blue),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(code,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                letterSpacing: 3)),
        const SizedBox(height: 6),
        Container(height: 2, color: Colors.blue),
        const SizedBox(height: 6),
        Text(keyText,
            style: const TextStyle(
                fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget uploadMultiAttachment() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isGuest
            ? "សូមថតឡានមុខក្រោយ (អតិបរមា $maxFiles ឯកសារ)"
            : "សូមថតកាតគ្រីឡាន, អត្តសញ្ញាណប័ណ្ណ​និងឯកសារពាក់ព័ន្ធ (អតិបរមា $maxFiles ឯកសារ)"),
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
                  width: 1.5),
            ),
            child: Column(children: [
              const Icon(Icons.upload_file, size: 40, color: Colors.green),
              const SizedBox(height: 10),
              Text("ចុចដើម្បីជ្រើសឯកសារ (${attachFiles.length}/$maxFiles)",
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text("PNG, JPG, PDF (≤ 5MB)",
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(
            attachFileNames.length,
            (i) => Row(children: [
                  Expanded(
                      child: Text(attachFileNames[i],
                          overflow: TextOverflow.ellipsis)),
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => removeAttachFileAt(i)),
                ])),
        if (attachFilesError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(attachFilesError!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ]),
    );
  }

  Widget uploadCameraAttachment() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  width: 1.5),
            ),
            child: const Column(children: [
              Icon(Icons.camera_alt, size: 40, color: Colors.blue),
              SizedBox(height: 10),
              Text("ចុចដើម្បីថតរូប",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Text("Camera Image (≤ 5MB)",
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
        ),
        if (cameraFileName != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: Text(cameraFileName!, overflow: TextOverflow.ellipsis)),
            IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: clearCamera),
          ]),
        ],
        if (cameraError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(cameraError!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ]),
    );
  }

  Widget _header() {
    return Container(
      height: 340,
      width: double.infinity,
      decoration: const BoxDecoration(color: Color(0xFF06175F)),
      child: Column(children: [
        const SizedBox(height: 55),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white),
                child: Image.asset('assets/img/about-moi-logo.png', height: 90),
              )),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ក្រសួងមហាផ្ទៃ',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xffDFB73B))),
            SizedBox(height: 8),
            Text('Ministry of Interior',
                style: TextStyle(
                    fontSize: 18,
                    color: Color(0xffDFB73B),
                    fontWeight: FontWeight.bold)),
          ]),
        ]),
        const SizedBox(height: 10),
        const Text("ទម្រង់ការស្នើរសំុបំពេញបែបបទចេញចូល​",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 5),
        const Text("ទីស្តីការក្រសួងមហាផ្ទៃ",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ]),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 20,
                color: Color(0xffDD7B25),
                fontWeight: FontWeight.bold)),
        const Divider(),
      ]),
    );
  }

  Widget dropdownUserType() {
    String labelOf(String v) {
      switch (v) {
        case "SECRETARY":
          return "រដ្ឋលេខាធិការក្រសួងមហាផ្ទៃ";
        case "DEPUTY_SECRETARY":
          return "អនុរដ្ឋលេខាធិការ​ ក្រសួងមហាផ្ទៃ";
        case "INSIDE_OFFICER":
          return "មន្រ្តីបំរើការងារនៅក្នុងទីស្តីការក្រសួងមហាផ្ទៃ";
        case "OUTSIDE_OFFICER":
          return "មន្រ្តីបំរើការងារនៅក្រៅទីស្តីការក្រសួងមហាផ្ទៃ";
        case "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER":
          return "មន្ត្រីរដ្ឋបាលថ្នាក់ក្រោមជាតិ";
        case "GUEST":
          return "ភ្ញៀវ";
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
                  child: Text(labelOf(v),
                      overflow: TextOverflow.ellipsis, maxLines: 2),
                ))
            .toList(),
        onChanged: (v) async {
          if (v == null) return;
          setState(() {
            _userType = v;
            selectedDurationDays = null;
            durationError = null;
            if (!(v == "INSIDE_OFFICER" || v == "OUTSIDE_OFFICER"))
              idNumberController.clear();
            final shouldShowWork = v == "INSIDE_OFFICER" ||
                v == "OUTSIDE_OFFICER" ||
                v == "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER" ||
                (v == "GUEST" && showWorkFieldsForGuest);
            if (!shouldShowWork) {
              ministryController.clear();
              departmentController.clear();
              officeController.clear();
              positionController.clear();
            }
            if (v != "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER")
              provinceCityController.clear();
            requestDateController.clear();
            durationDaysController.clear();
            attachFiles.clear();
            attachFileNames.clear();
            attachFilesError = null;
            cameraFile = null;
            cameraFileName = null;
            cameraError = null;
            _resetWorkDropdownStateAndControllers();
          });
          await _loadWorkDropdownsIfNeeded(userTypeOverride: v);
        },
      ),
    );
  }

  Widget bottom() {
    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          Expanded(
              child: SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06175F),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: submitRegister,
              child: const Text("ដាក់ស្នើ",
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          )),
        ]),
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
