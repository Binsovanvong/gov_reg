import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gov_reg/routes/approute.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ✅ MUST be top-level (NOT inside State class)
class _VehicleForm {
  final brand = TextEditingController();
  final plate = TextEditingController();
  final color = TextEditingController();
  final year = TextEditingController();

  String vehicleType = "CAR";
  String carPlateType = "REGULAR";

  /// ✅ must match motoPlateTypes keys
  String motoPlateType = "REGULAR";

  String? carPlateSubcategory;
  String? motoPlateSubcategory;

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
    "SECRETARY",
    "DEPUTY_SECRETARY",
    "INSIDE_OFFICER",
    "OUTSIDE_OFFICER",
    "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER",
    "GUEST",
  ];

  /// ✅ Backend requires attachmentTypes for EACH file uploaded
  static const String attachmentTypeVehicle = "VEHICLE_DOCUMENT";

  /// ✅ Selfie = INVITATION_DOCUMENT (as you requested)
  static const String attachmentTypeSelfie = "INVITATION_DOCUMENT";

  // ✅ demo login creds
  static const String _apiEmail = "user@moi.com";
  static const String _apiPassword = "Moi@2026\$";

  String _userType = "GUEST";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWorkDropdownsIfNeeded(userTypeOverride: _userType);
  }

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
  final searchController = TextEditingController();

  /// (kept but no longer used for officer/secretary/deputy)
  final requestDateController = TextEditingController();

  final provinceCityController = TextEditingController();
  final reasonController = TextEditingController();

  /// (kept but replaced by dropdown for Guest/National)
  final durationDaysController = TextEditingController();

  // ✅ NEW: duration dropdown for Guest/National (1..7)
  int? selectedDurationDays; // 1..7
  String? durationError;

  // Vehicles list
  final List<_VehicleForm> vehicles = [_VehicleForm()];

  // ✅ Save computed dates so we can pass to next screen
  int _lastRequestDateInt = 0; // yyyymmdd
  String? _lastRequestAtDateStr; // dd-MM-yyyy or null

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

  void _syncWorkControllersFromDropdownIfNeeded() {
    if (!useWorkDropdown) return;
    if (selectedGD != null) ministryController.text = selectedGD!.name;
    if (selectedDept != null) departmentController.text = selectedDept!.name;
    if (selectedBurau != null) officeController.text = selectedBurau!.name;
    if (selectedPos != null) positionController.text = selectedPos!.name;
  }

  // ----------------------------
  // Plate Types
  // ----------------------------
  final List<Map<String, dynamic>> plateCategory = [
    {"key": "ROYAL_PALACE", "label": "រាជវាំង", "subcategory": ["ROYAL_PALACE"]},
    {
      "key": "STATE",
      "label": "រដ្ឋ",
      "subcategory": List.generate(61, (i) => "STATE_${i + 1}"),
    },
    {"key": "POLICE", "label": "នគរបាល", "subcategory": ["POLICE"]},
    {
      "key": "ARMY_FORCE",
      "label": "ខេមរភូមិន្ទ",
      "subcategory": List.generate(9, (i) => "R C A F_${i + 1}"),
    },
    {
      "key": "ORGANIZATION",
      "label": "អង្គការ",
      "subcategory": ["OI", "ONG1", "ONG2"],
    },
    {"key": "EMBASSY", "label": "អង្គទូត", "subcategory": ["CMD01-1", "CD01"]},
    {
      "key": "UNITED_NATIONS",
      "label": "អង្គការសហប្រជាជាតិ",
      "subcategory": ["OUN01-1", "ONU01"],
    },
    {"key": "TEMPORARY", "label": "បណ្តោះអាសន្ន", "subcategory": ["AT18"]},
    {
      "key": "REGULAR",
      "label": "ធម្មតា",
      "subcategory": [
        "PHNOM PENH",
        "KANDAL",
        "BANTEAY MEANCHEY",
        "BATTAMBANG",
        "KAMPONG CHAM",
        "KAMPONG CHHNANG",
        "KAMPONG SPEU",
        "KAMPONG THOM",
        "KAMPOT",
        "KEP",
        "KOH KONG",
        "KRATIE",
        "MONDULKIRI",
        "ODDAR MEANCHEY",
        "PAILIN",
        "SIHANOUKVILLE",
        "PREAH VIHEAR",
        "PREY VENG",
        "PURSAT",
        "SIEM REAP",
        "STUNG TRENG",
        "SVAY RIENG",
        "TAKEO",
        "TBOUNG KHMUM",
        "RATANAKIRI",
      ],
    },
    {"key": "CAMBODIA", "label": "កម្ពុជា", "subcategory": ["CAMBODIA"]},
  ];

  final List<Map<String, dynamic>> motoPlateTypes = [
    {
      "key": "REGULAR",
      "label": "ធម្មតា",
      "subcategory": [
        "PHNOM PENH_M",
        "KANDAL_M",
        "BANTEAY MEANCHEY_M",
        "BATTAMBANG_M",
        "KAMPONG CHAM_M",
        "KAMPONG CHHNANG_M",
        "KAMPONG SPEU_M",
        "KAMPONG THOM_M",
        "KAMPOT_M",
        "KEP_M",
        "KOH KONG_M",
        "KRATIE_M",
        "MONDULKIRI_M",
        "ODDAR MEANCHEY_M",
        "PAILIN_M",
        "SIHANOUKVILLE_M",
        "PREAH VIHEAR_M",
        "PREY VENG_M",
        "PURSAT_M",
        "SIEM REAP_M",
        "STUNG TRENG_M",
        "SVAY RIENG_M",
        "TAKEO_M",
        "TBOUNG KHMUM_M",
        "RATANAKIRI_M",
      ],
    },
    {"key": "CAMBODIA", "label": "កម្ពុជា", "subcategory": ["CAMBODIA_M"]},
    {"key": "POLICE", "label": "នគរបាល", "subcategory": ["POLICE_M"]},
    {"key": "ARMY_FORCE", "label": "ខេមរភូមិន្ទ", "subcategory": ["R C A F_M"]},
  ];

  String getPlateKey(_VehicleForm v) {
    final isMoto = v.vehicleType == "MOTORBIKE";
    final items = isMoto ? motoPlateTypes : plateCategory;
    final type = isMoto ? v.motoPlateType : v.carPlateType;

    final found = items.firstWhere(
      (item) => item["key"] == type,
      orElse: () => {"key": "UNKNOWN"},
    );

    return (found["key"] ?? "UNKNOWN").toString();
  }

  /// DB code to send as plateSubCategory
  String? getSubcategoryKey(_VehicleForm v) {
    final isMoto = v.vehicleType == "MOTORBIKE";
    final items = isMoto ? motoPlateTypes : plateCategory;
    final type = isMoto ? v.motoPlateType : v.carPlateType;
    final sub = isMoto ? v.motoPlateSubcategory : v.carPlateSubcategory;

    final found = items.firstWhere(
      (item) => item["key"] == type,
      orElse: () => <String, dynamic>{},
    );

    if (found.isEmpty) return null;

    final list =
        (found["subcategory"] as List?)?.cast<String>() ?? const <String>[];

    // selected
    if (sub != null && sub.trim().isNotEmpty && list.contains(sub)) return sub;

    // auto if only one
    if (list.length == 1) return list[0];

    return null;
  }

  /// Maps DB code → Khmer display label
  static const Map<String, String> _subcategoryLabels = {
    "ROYAL_PALACE": "រាជវាំង",
    "STATE_1": "រដ្ឋ-01",
    "STATE_2": "រដ្ឋ-02",
    "STATE_3": "រដ្ឋ-03",
    "STATE_4": "រដ្ឋ-04",
    "STATE_5": "រដ្ឋ-05",
    "STATE_6": "រដ្ឋ-06",
    "STATE_7": "រដ្ឋ-07",
    "STATE_8": "រដ្ឋ-08",
    "STATE_9": "រដ្ឋ-09",
    "STATE_10": "រដ្ឋ-10",
    "STATE_11": "រដ្ឋ-11",
    "STATE_12": "រដ្ឋ-12",
    "STATE_13": "រដ្ឋ-13",
    "STATE_14": "រដ្ឋ-14",
    "STATE_15": "រដ្ឋ-15",
    "STATE_16": "រដ្ឋ-16",
    "STATE_17": "រដ្ឋ-17",
    "STATE_18": "រដ្ឋ-18",
    "STATE_19": "រដ្ឋ-19",
    "STATE_20": "រដ្ឋ-20",
    "STATE_21": "រដ្ឋ-21",
    "STATE_22": "រដ្ឋ-22",
    "STATE_23": "រដ្ឋ-23",
    "STATE_24": "រដ្ឋ-24",
    "STATE_25": "រដ្ឋ-25",
    "STATE_26": "រដ្ឋ-26",
    "STATE_27": "រដ្ឋ-27",
    "STATE_28": "រដ្ឋ-28",
    "STATE_29": "រដ្ឋ-29",
    "STATE_30": "រដ្ឋ-30",
    "STATE_31": "រដ្ឋ-31",
    "STATE_32": "រដ្ឋ-32",
    "STATE_33": "រដ្ឋ-33",
    "STATE_34": "រដ្ឋ-34",
    "STATE_35": "រដ្ឋ-35",
    "STATE_36": "រដ្ឋ-36",
    "STATE_37": "រដ្ឋ-37",
    "STATE_38": "រដ្ឋ-38",
    "STATE_39": "រដ្ឋ-39",
    "STATE_40": "រដ្ឋ-40",
    "STATE_41": "រដ្ឋ-41",
    "STATE_42": "រដ្ឋ-42",
    "STATE_43": "រដ្ឋ-43",
    "STATE_44": "រដ្ឋ-44",
    "STATE_45": "រដ្ឋ-45",
    "STATE_46": "រដ្ឋ-46",
    "STATE_47": "រដ្ឋ-47",
    "STATE_48": "រដ្ឋ-48",
    "STATE_49": "រដ្ឋ-49",
    "STATE_50": "រដ្ឋ-50",
    "STATE_51": "រដ្ឋ-51",
    "STATE_52": "រដ្ឋ-52",
    "STATE_53": "រដ្ឋ-53",
    "STATE_54": "រដ្ឋ-54",
    "STATE_55": "រដ្ឋ-55",
    "STATE_56": "រដ្ឋ-56",
    "STATE_57": "រដ្ឋ-57",
    "STATE_58": "រដ្ឋ-58",
    "STATE_59": "រដ្ឋ-59",
    "STATE_60": "រដ្ឋ-60",
    "STATE_61": "រដ្ឋ-61",
    "POLICE": "នគរបាល",
    "POLICE_M": "នគរបាល",
    "R C A F_1": "ខេមរភូមិន្ទ-01",
    "R C A F_2": "ខេមរភូមិន្ទ-02",
    "R C A F_3": "ខេមរភូមិន្ទ-03",
    "R C A F_4": "ខេមរភូមិន្ទ-04",
    "R C A F_5": "ខេមរភូមិន្ទ-05",
    "R C A F_6": "ខេមរភូមិន្ទ-06",
    "R C A F_7": "ខេមរភូមិន្ទ-07",
    "R C A F_8": "ខេមរភូមិន្ទ-08",
    "R C A F_9": "ខេមរភូមិន្ទ-09",
    "R C A F_M": "ខេមរភូមិន្ទ",
    "OI": "OI",
    "ONG1": "ONG1",
    "ONG2": "ONG2",
    "CMD01-1": "CMD01-1",
    "CD01": "CD01",
    "OUN01-1": "OUN01-1",
    "ONU01": "ONU01",
    "AT18": "AT18",
    "PHNOM PENH": "ភ្នំពេញ",
    "KANDAL": "កណ្ដាល",
    "BANTEAY MEANCHEY": "បន្ទាយមានជ័យ",
    "BATTAMBANG": "បាត់ដំបង",
    "KAMPONG CHAM": "កំពង់ចាម",
    "KAMPONG CHHNANG": "កំពង់ឆ្នាំង",
    "KAMPONG SPEU": "កំពង់ស្ពឺ",
    "KAMPONG THOM": "កំពង់ធំ",
    "KAMPOT": "កំពត",
    "KEP": "កែប",
    "KOH KONG": "កោះកុង",
    "KRATIE": "ក្រចេះ",
    "MONDULKIRI": "មណ្ឌលគិរី",
    "ODDAR MEANCHEY": "ឧត្តរមានជ័យ",
    "PAILIN": "ប៉ៃលិន",
    "SIHANOUKVILLE": "ព្រះសីហនុ",
    "PREAH VIHEAR": "ព្រះវិហារ",
    "PREY VENG": "ព្រៃវែង",
    "PURSAT": "ពោធិ៍សាត់",
    "SIEM REAP": "សៀមរាប",
    "STUNG TRENG": "ស្ទឹងត្រែង",
    "SVAY RIENG": "ស្វាយរៀង",
    "TAKEO": "តាកែវ",
    "TBOUNG KHMUM": "ត្បូងឃ្មុំ",
    "RATANAKIRI": "រតនគិរី",
    "PHNOM PENH_M": "ភ្នំពេញ",
    "KANDAL_M": "កណ្ដាល",
    "BANTEAY MEANCHEY_M": "បន្ទាយមានជ័យ",
    "BATTAMBANG_M": "បាត់ដំបង",
    "KAMPONG CHAM_M": "កំពង់ចាម",
    "KAMPONG CHHNANG_M": "កំពង់ឆ្នាំង",
    "KAMPONG SPEU_M": "កំពង់ស្ពឺ",
    "KAMPONG THOM_M": "កំពង់ធំ",
    "KAMPOT_M": "កំពត",
    "KEP_M": "កែប",
    "KOH KONG_M": "កោះកុង",
    "KRATIE_M": "ក្រចេះ",
    "MONDULKIRI_M": "មណ្ឌលគិរី",
    "ODDAR MEANCHEY_M": "ឧត្តរមានជ័យ",
    "PAILIN_M": "ប៉ៃលិន",
    "SIHANOUKVILLE_M": "ព្រះសីហនុ",
    "PREAH VIHEAR_M": "ព្រះវិហារ",
    "PREY VENG_M": "ព្រៃវែង",
    "PURSAT_M": "ពោធិ៍សាត់",
    "SIEM REAP_M": "សៀមរាប",
    "STUNG TRENG_M": "ស្ទឹងត្រែង",
    "SVAY RIENG_M": "ស្វាយរៀង",
    "TAKEO_M": "តាកែវ",
    "TBOUNG KHMUM_M": "ត្បូងឃ្មុំ",
    "RATANAKIRI_M": "រតនគិរី",
    "CAMBODIA": "កម្ពុជា",
    "CAMBODIA_M": "កម្ពុជា",
  };

  String subcategoryLabel(String? code) {
    if (code == null || code.isEmpty) return "";
    return _subcategoryLabels[code] ?? code;
  }

  // ----------------------------
  // ✅ Rules
  // ----------------------------
  bool get isGuest => _userType == "GUEST";
  bool get isInsideOfficer => _userType == "INSIDE_OFFICER";
  bool get isOutsideOfficer => _userType == "OUTSIDE_OFFICER";
  bool get isOfficer => isInsideOfficer || isOutsideOfficer;

  bool get isSecretaryOrDeputy =>
      _userType == "SECRETARY" || _userType == "DEPUTY_SECRETARY";

  bool get isNational =>
      _userType == "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER";

  static const bool showWorkFieldsForGuest = true;

  bool get showIdNumber => isOfficer;

  bool get showWorkFields =>
      isOfficer || isNational || (isGuest && showWorkFieldsForGuest);

  bool get showProvinceCity => isNational;

  /// ✅ ONLY Guest + National uses duration (now via dropdown 1..7)
  bool get useDurationDays => isNational || isGuest;

  bool get selfieRequired => isGuest;

  bool get useWorkDropdown => isOfficer;

  // ----------------------------
  // Helpers
  // ----------------------------
  String _normalizePlate(String s) =>
      s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int _fmtYmdInt(DateTime d) => int.parse(
      "${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}");

  String _fmtDmy(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";

  // ----------------------------
  // ✅ Plate Validation + Formatter
  // ----------------------------
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
    final isMoto = v.vehicleType == "MOTORBIKE";
    if (!isMoto) return v.carPlateType;

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
    final ruleKey = _ruleKeyForVehicle(v);
    final p = _normalizePlate(plate);
    final rules = _categoryRules[ruleKey];
    if (rules == null) return true;
    return rules.any((r) => r.hasMatch(p));
  }

  String _formatPlateLive(_VehicleForm v, String raw) {
    final ruleKey = _ruleKeyForVehicle(v);
    final upper = raw.toUpperCase();

    if (ruleKey.contains("CAMBODIA")) {
      return upper.replaceAll(RegExp(r'[^A-Z0-9.]'), '');
    }

    var cleaned = upper.replaceAll(RegExp(r'[^A-Z0-9-]'), '');
    cleaned = cleaned.replaceAll('-', '');

    final isGov = ruleKey == "STATE" ||
        ruleKey == "POLICE" ||
        ruleKey == "ARMY_FORCE" ||
        ruleKey == "MOTORBIKE_POLICE" ||
        ruleKey == "MOTORBIKE_ARMY_FORCE";

    if (isGov) {
      if (cleaned.length <= 1) return cleaned;
      final d = cleaned.substring(0, 1);
      final nums = cleaned.substring(1);
      return '$d-$nums';
    }

    if (cleaned.isEmpty) return '';
    final first = cleaned.substring(0, 1);
    final rest = cleaned.substring(1);

    final letters = (RegExp(r'^[A-Z]{0,2}').stringMatch(rest) ?? '');
    final tail = rest.substring(letters.length);
    final nums = tail.replaceAll(RegExp(r'[^0-9]'), '');

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
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }),
    ];
  }

  // ----------------------------
  // AUTH
  // ----------------------------
  Future<http.Response> _login({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse("$baseUrl/api/auth/authenticate");
    final res = await http.post(
      uri,
      headers: const {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"email": email, "password": password}),
    );
    return res;
  }

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
      body: jsonEncode({"refreshToken": refreshToken, "token": refreshToken}),
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
            (data["token"]["accessToken"] ?? data["token"]["token"] ?? "")
                .toString();
      }
    }

    if (newAccessToken.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("accessToken", newAccessToken);
    return newAccessToken;
  }

  Future<Map<String, String>> _extractAndSaveTokens(String body) async {
    try {
      final data = jsonDecode(body);

      String access = "";
      String refresh = "";

      if (data is Map) {
        access = (data["accessToken"] ?? "").toString();
        refresh = (data["refreshToken"] ?? "").toString();

        if (access.isEmpty) {
          final token = data["token"];
          if (token is String) {
            access = token;
          } else if (token is Map) {
            access = (token["accessToken"] ?? token["token"] ?? "").toString();
            refresh = (token["refreshToken"] ?? refresh).toString();
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      if (access.isNotEmpty) await prefs.setString("accessToken", access);
      if (refresh.isNotEmpty) await prefs.setString("refreshToken", refresh);

      return {"access": access, "refresh": refresh};
    } catch (e) {
      debugPrint("Token parse failed: $e");
      return {"access": "", "refresh": ""};
    }
  }

  Future<void> forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("accessToken");
    await prefs.remove("refreshToken");
    await prefs.clear();
    if (!mounted) return;
    _snack("Session expired. Please login again.");
  }

  Future<void> _ensureAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString("accessToken") ?? "";
    if (existing.isNotEmpty) return;

    final loginRes = await _login(
      baseUrl: baseUrl,
      email: _apiEmail,
      password: _apiPassword,
    );

    if (loginRes.statusCode == 200) {
      await _extractAndSaveTokens(loginRes.body);
    } else {
      debugPrint("EnsureAuth login failed: ${loginRes.statusCode} ${loginRes.body}");
      if (mounted) _snack("Login Failed: ${loginRes.statusCode}");
    }
  }

  Future<http.Response> _getWithAuthRetry(Uri uri) async {
    final prefs = await SharedPreferences.getInstance();
    String token = prefs.getString("accessToken") ?? "";

    Future<http.Response> doGet(String t) {
      return http.get(
        uri,
        headers: {
          "Accept": "application/json",
          // if (t.isNotEmpty) "Authorization": "Bearer $t",
        },
      );
    }

    var res = await doGet(token);

    if (res.statusCode == 401 &&
        (res.body.contains("JWT token has expired") ||
            res.body.contains("JWT expired"))) {
      final newToken = await _refreshAccessToken();
      if (newToken == null || newToken.isEmpty) {
        await forceLogout();
        return res;
      }
      res = await doGet(newToken);
    }

    if (res.statusCode == 401) {
      if ((prefs.getString("accessToken") ?? "").isNotEmpty) {
        await forceLogout();
      }
    }

    return res;
  }

  // ----------------------------
  // ✅ Search API
  // ----------------------------
  Future<http.Response> _search({required String search}) async {
    final uri = Uri.parse("$baseUrl/api/v1/parking-card-requests/search/$search");
    await _ensureAuth();

    try {
      final res = await _getWithAuthRetry(uri);

      if (res.statusCode == 200) {
        _snack("ស្វែងរកជោគជ័យ (Search Successful)");
        final Map<String, dynamic> responseData = jsonDecode(res.body);

        if (!mounted) return res;

        Navigator.pushNamed(
          context,
          Approute.verifySuccessScreen,
          arguments: {
            "code": responseData["code"],
            "token": responseData["token"],
            "parkingRequestStatus": responseData["parkingRequestStatus"],
            "fullName": responseData["name"],
            "phone": responseData["phone"],
            "userType": responseData["userType"],
            "selfieBytes": null,
            "selfiePath": null,
            "requestDate": responseData["requestDate"],
            "requestAtDate": responseData["requestAtDate"],
            "vehicleType": (responseData["vehicles"] as List).isNotEmpty
                ? responseData["vehicles"][0]["vehicleType"]
                : "",
            "workingInfo": {
              "generalDepartmentText":
                  responseData["generalDepartmentText"] ??
                      responseData["generalDepartment"] ??
                      responseData["organization"],
              "departmentText":
                  responseData["departmentText"] ?? responseData["department"],
              "burauText": responseData["burauText"] ?? responseData["burau"],
              "positionText":
                  responseData["positionText"] ?? responseData["position"],
              "policeId": responseData["policeId"],
              "provinceCity": responseData["provinceCity"],
            },
            "vehicles": responseData["vehicles"],
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
      return res;
    } catch (e) {
      _snack("(Connection Error)");
      return http.Response('{"error": "Connection failed"}', 500);
    }
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
    return decoded
        .map((e) => DepartmentItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BurauItem>> fetchBuraus() async {
    final uri = Uri.parse("$baseUrl/api/v1/bureaus");
    final res = await _getWithAuthRetry(uri);
    if (res.statusCode != 200) {
      throw "Buraus HTTP ${res.statusCode}: ${res.body}";
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .map((e) => BurauItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PositionItem>> fetchPositions() async {
    final uri = Uri.parse("$baseUrl/api/v1/positions");
    final res = await _getWithAuthRetry(uri);
    if (res.statusCode != 200) {
      throw "Positions HTTP ${res.statusCode}: ${res.body}";
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .map((e) => PositionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _loadWorkDropdownsIfNeeded({String? userTypeOverride}) async {
    final type = userTypeOverride ?? _userType;
    final shouldUseDropdown =
        (type == "INSIDE_OFFICER" || type == "OUTSIDE_OFFICER");
    if (!shouldUseDropdown) return;

    await _ensureAuth();

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

      burauFiltered =
          burauAll.where((b) => b.departmentId == (d?.id ?? -1)).toList();
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

  // ✅ Camera
  Future<void> pickCameraImage() async {
    setState(() => cameraError = null);

    final XFile? xfile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2000,
      maxHeight: 2000,
    );

    if (xfile == null) return;

    File file = File(xfile.path);

    const maxBytes = 5 * 1024 * 1024;
    int bytes = await file.length();
    if (bytes > maxBytes) {
      setState(() => cameraError = "រូបភាពត្រូវ ≤ 5MB");
      return;
    }

    const minBytes = 153600;
    if (bytes < minBytes) {
      img.Image? decoded = img.decodeImage(await file.readAsBytes());

      if (decoded == null) {
        setState(() => cameraError = "មិនអាចដំណើរការរូបភាពបាន");
        return;
      }

      int attempt = 0;
      const maxAttempts = 5;

      while (bytes < minBytes && attempt < maxAttempts) {
        decoded = img.copyResize(
          decoded!,
          width: (decoded.width * 1.1).toInt(),
          height: (decoded.height * 1.1).toInt(),
        );

        final newBytes = img.encodeJpg(decoded, quality: 100);
        await file.writeAsBytes(newBytes);
        bytes = await file.length();
        attempt++;
      }

      if (bytes < minBytes) {
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
  // ✅ validateForm (UPDATED)
  // ----------------------------
  bool validateForm() {
    setState(() => durationError = null);

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

    // ✅ Guest + National must select duration 1..7 (dropdown)
    if (useDurationDays) {
      if (selectedDurationDays == null ||
          selectedDurationDays! < 1 ||
          selectedDurationDays! > 7) {
        setState(() => durationError = "សូមជ្រើសរយៈពេល ១-៧ ថ្ងៃ");
        _snack("សូមជ្រើសរយៈពេល ១-៧ ថ្ងៃ");
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
Future<Map<String, dynamic>> createParkingCardRequest() async {
  final token = await _getToken();
  if (token == null || token.isEmpty) {
    throw Exception("Unauthorized: no access token");
  }

  _syncWorkControllersFromDropdownIfNeeded();

  final List<String> attachmentTypes = [
    ...List.filled(attachFiles.length, attachmentTypeVehicle),
    if (cameraFile != null) attachmentTypeSelfie,
  ];

  String queryString = "";
  if (attachmentTypes.isNotEmpty) {
    final parts = attachmentTypes
        .map((e) => "attachmentTypes=${Uri.encodeQueryComponent(e)}")
        .toList();
    queryString = "?${parts.join("&")}";
  }

  final uri = Uri.parse("$baseUrl/api/v1/parking-card-requests$queryString");

  final now = DateTime.now();
  late final DateTime requestAt;
  late final DateTime requestEnd;

  if (useDurationDays) {
    final dur = selectedDurationDays ?? 1;
    requestAt = now;
    requestEnd = requestAt.add(Duration(days: dur));
  } else {
    requestAt = now;
    requestEnd = DateTime(now.year + 1, now.month, now.day);
  }

  final int requestDateInt = _fmtYmdInt(requestEnd);
  final String requestAtDateStr = _fmtDmy(requestAt);

  _lastRequestDateInt = requestDateInt;
  _lastRequestAtDateStr = requestAtDateStr;

  String gdText = ministryController.text.trim();
  String deptText = departmentController.text.trim();
  String bureauText = officeController.text.trim();
  String posText = positionController.text.trim();

  final String policeIdVal = idNumberController.text.trim();
  final String provinceVal = provinceCityController.text.trim();

  if (showWorkFields) {
    gdText = gdText.isEmpty ? "-" : gdText;
    deptText = deptText.isEmpty ? "-" : deptText;
    bureauText = bureauText.isEmpty ? "-" : bureauText;
    posText = posText.isEmpty ? "-" : posText;
  } else {
    gdText = "";
    deptText = "";
    bureauText = "";
    posText = "";
  }

  final Map<String, dynamic> dto = {
    "reason": reasonController.text.trim().isEmpty
        ? "Parking card request"
        : reasonController.text.trim(),
    "requestDate": requestDateInt,
    if (_userType != "GUEST") "requestAtDate": requestAtDateStr,
    "user": {
      "name": fullNameController.text.trim(),
      "phone": phoneController.text.trim(),
      "userType": _userType,
    },
    "workingInfo": {
      "policeId": showIdNumber ? policeIdVal : "",
      "generalDepartmentText": gdText,
      "departmentText": deptText,
      "bureauText": bureauText,
      "positionText": posText,
      "generalDepartment": useWorkDropdown ? (selectedGD?.id ?? 0) : 0,
      "department": useWorkDropdown ? (selectedDept?.id ?? 0) : 0,
      "bureau": useWorkDropdown ? (selectedBurau?.id ?? 0) : 0,
      "position": useWorkDropdown ? (selectedPos?.id ?? 0) : 0,
      "provinceCity": showProvinceCity ? provinceVal : "",
    },
    "vehicles": vehicles.map((v) {
      return {
        "brand": v.brand.text.trim(),
        "plate": {
          "plateNumber": _normalizePlate(v.plate.text),
          "plateCategory":
              v.vehicleType == "MOTORBIKE" ? v.motoPlateType : v.carPlateType,
          "plateSubCategory": getSubcategoryKey(v),
        },
        "color": v.color.text.trim(),
        "madeYear": int.tryParse(v.year.text.trim()) ?? 0,
        "vehicleType": v.vehicleType,
      };
    }).toList(),
  };

  debugPrint("URI = $uri");
  debugPrint("DTO SENT = ${jsonEncode(dto)}");

  final request = http.MultipartRequest("POST", uri);
  request.headers["Authorization"] = "Bearer $token";
  request.headers["Accept"] = "application/json";

  request.files.add(
    http.MultipartFile.fromString(
      "dto",
      jsonEncode(dto),
      filename: "dto.json",
      contentType: MediaType("application", "json"),
    ),
  );

  for (int i = 0; i < attachFiles.length; i++) {
    request.files.add(
      await http.MultipartFile.fromPath(
        "files",
        attachFiles[i].path,
        filename: attachFileNames[i],
      ),
    );
  }

  if (cameraFile != null) {
    request.files.add(
      await http.MultipartFile.fromPath(
        "files",
        cameraFile!.path,
        filename: cameraFileName ?? cameraFile!.path.split("/").last,
      ),
    );
  }

  final streamed = await request.send();
  final resp = await http.Response.fromStream(streamed);

  debugPrint("STATUS: ${resp.statusCode}");
  debugPrint("BODY: ${resp.body}");

  if (resp.statusCode != 200 && resp.statusCode != 201) {
    throw Exception("HTTP ${resp.statusCode}: ${resp.body}");
  }

  if (resp.body.isEmpty) return {};

  final decoded = jsonDecode(resp.body);
  return decoded is Map<String, dynamic> ? decoded : {};
}
Future<void> submitRegister() async {
  debugPrint("SUBMIT pressed");

  await _ensureAuth();
  _syncWorkControllersFromDropdownIfNeeded();

  if (!validateForm()) return;

  setState(() => isLoading = true);

  try {
    final res = await createParkingCardRequest();
    if (!mounted) return;

    Uint8List? selfieBytes;
    if (cameraFile != null) {
      selfieBytes = await cameraFile!.readAsBytes();
    }

    String fallbackText(
      dynamic apiValue,
      String controllerValue, {
      String defaultValue = "-",
    }) {
      final api = (apiValue ?? "").toString().trim();
      if (api.isNotEmpty && api.toLowerCase() != "null") {
        return api;
      }

      final local = controllerValue.trim();
      if (local.isNotEmpty) {
        return local;
      }

      return defaultValue;
    }

    final List<dynamic> resVehicles =
        (res["vehicles"] is List) ? (res["vehicles"] as List) : <dynamic>[];

    Navigator.pushNamed(
      context,
      Approute.verifySuccessScreen,
      arguments: {
        "code": res["code"],
        "token": res["token"],
        "parkingRequestStatus": res["parkingRequestStatus"],
        "fullName": (res["name"] ?? fullNameController.text.trim()).toString(),
        "phone": (res["phone"] ?? phoneController.text.trim()).toString(),
        "userType": (res["userType"] ?? _userType).toString(),
        "selfieBytes": selfieBytes,
        "selfiePath": cameraFile?.path,
        "requestDate": res["requestDate"] ?? _lastRequestDateInt,
        "requestAtDate": res["requestAtDate"] ?? _lastRequestAtDateStr,
        "vehicleType": (resVehicles.isNotEmpty && resVehicles.first is Map)
            ? ((resVehicles.first as Map)["vehicleType"] ?? "").toString()
            : (vehicles.isNotEmpty ? vehicles.first.vehicleType : ""),
        "workingInfo": {
          "generalDepartmentText": fallbackText(
            res["generalDepartmentText"],
            ministryController.text,
          ),
          "departmentText": fallbackText(
            res["departmentText"],
            departmentController.text,
          ),
          "bureauText": fallbackText(
            res["bureauText"],
            officeController.text,
          ),
          "positionText": fallbackText(
            res["positionText"],
            positionController.text,
          ),
          "policeId": fallbackText(
            res["policeId"],
            idNumberController.text,
            defaultValue: "",
          ),
          "provinceCity": fallbackText(
            res["provinceCity"],
            provinceCityController.text,
          ),
        },
        "vehicles": resVehicles,
      },
    );
  } catch (e) {
    debugPrint("SUBMIT ERROR: $e");
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  } finally {
    if (mounted) {
      setState(() => isLoading = false);
    }
  }
}
  // ----------------------------
  // ✅ UI BLOCKS
  // ----------------------------
  Widget fieldBlock({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          child,
        ],
      ),
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

  // ----------------------------
  // UI
  // ----------------------------
@override
Widget build(BuildContext context) {
  if (!allowedUserTypes.contains(_userType)) _userType = "GUEST";

  return Scaffold(
    backgroundColor: Colors.grey.shade100,
    body: SingleChildScrollView(
      child: Column(
        children: [
          _header(),

          // ✅ FORM ON APPBAR (overlap header)
          Transform.translate(
            offset: const Offset(0, -60), // change -50/-70 to adjust
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
                      color: Colors.black12,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10),
                    // ✅ SEARCH
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: searchController,
                              decoration: inputDecoration(
                                "តាមរយះ លេខកូដ ឬលេខទូរស័ព្ទ",
                              ).copyWith(
                                prefixIcon: const Icon(Icons.search),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 48,
                            width: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                _search(search: searchController.text);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                side: BorderSide(color: Colors.grey.shade400),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                                padding: EdgeInsets.zero,
                              ),
                              child: const Icon(Icons.search,
                                  size: 24, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    sectionTitle("ព័ត៌មានផ្ទាល់ខ្លួន"),
                    dropdownUserType(),
                    const SizedBox(height: 15),

                    // ✅ NAME
                    oneInput(
                      label: "គោត្តនាម និងនាម",
                      hint: "បញ្ចូលឈ្មោះពេញ",
                      controller: fullNameController,
                    ),

                    // ✅ ID NUMBER (only officer)
                    if (showIdNumber)
                      textFieldBlock(
                        label: "អត្តលេខ",
                        hint: "បញ្ចូលអត្តលេខ",
                        controller: idNumberController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        maxLength: 10,
                      ),

                    // ✅ WORK FIELDS
                    if (showWorkFields) ...[
                      sectionTitle("ព័ត៌មានការងារ"),
                      if (useWorkDropdown) ...[
                        if (dropdownLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            child: LinearProgressIndicator(),
                          ),
                        _ddGeneralDepartment(),
                        _ddDepartment(),
                        _ddBurau(),
                        _ddPosition(),
                      ] else ...[
                        oneInput(
                          label: "ក្រសួង/ស្ថាប័ន",
                          hint: "បញ្ចូលក្រសួង",
                          controller: ministryController,
                        ),
                        oneInput(
                          label: "នាយកដ្ឋាន/អង្គភាព",
                          hint: "បញ្ចូលនាយកដ្ឋាន",
                          controller: departmentController,
                        ),
                        oneInput(
                          label: "ការិយាល័យ",
                          hint: "បញ្ចូលការិយាល័យ",
                          controller: officeController,
                        ),
                        oneInput(
                          label: "តួនាទី",
                          hint: "បញ្ចូលតួនាទី",
                          controller: positionController,
                        ),
                      ],
                    ],

                    // ✅ PROVINCE CITY (National only)
                    if (showProvinceCity)
                      oneInput(
                        label: "ខេត្ត/រាជធានី",
                        hint: "បញ្ចូលខេត្ត/រាជធានី",
                        controller: provinceCityController,
                      ),

                    // ✅ PHONE
                    textFieldBlock(
                      label: "លេខទូរស័ព្ទ",
                      hint: "លេខទូរស័ព្ទ",
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                    ),

                    // ✅ DURATION (Guest + National)
                    if (useDurationDays) ...[
                      fieldBlock(
                        label: "រយៈពេលស្នើរ (១-៧ ថ្ងៃ)",
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          value: selectedDurationDays,
                          decoration: inputDecoration("ជ្រើសរយៈពេល ១-៧ ថ្ងៃ")
                              .copyWith(errorText: durationError),
                          items: List.generate(7, (i) {
                            final d = i + 1;
                            return DropdownMenuItem<int>(
                              value: d,
                              child: Text("$d ថ្ងៃ"),
                            );
                          }),
                          onChanged: (v) {
                            setState(() {
                              selectedDurationDays = v;
                              durationError = null;
                            });
                          },
                        ),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        child: Text(
                          "កាលបរិច្ឆេទស្នើរ៖ ស្វ័យប្រវត្តិ (ថ្ងៃនេះ) | ផុតកំណត់៖ ១ ឆ្នាំ",
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ),
                    ],

                    // ✅ VEHICLE SECTION
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
                                Text("រថយន្ត/ម៉ូតូ #${i + 1}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
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
                                  onChanged: (x) =>
                                      setState(() => v.vehicleType = x!),
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  value: "MOTORBIKE",
                                  groupValue: v.vehicleType,
                                  title: const Text("ម៉ូតូ"),
                                  onChanged: (x) =>
                                      setState(() => v.vehicleType = x!),
                                ),
                              ),
                            ],
                          ),
                          oneInput(
                            label: "ម៉ាក",
                            hint: "បញ្ចូលម៉ាក",
                            controller: v.brand,
                          ),
                          plateRow(v),
                          textFieldBlock(
                            label: "ផ្លាកលេខ",
                            hint: "សូមបញ្ចូលផ្លាកលេខ",
                            controller: v.plate,
                            inputFormatters: _plateFormatters(v),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: plateBox(
                              label: subcategoryLabel(getSubcategoryKey(v)),
                              code: _normalizePlate(v.plate.text).isEmpty
                                  ? "----"
                                  : _normalizePlate(v.plate.text),
                              keyText: getPlateKey(v),
                            ),
                          ),
                          oneInput(
                            label: "ពណ៌",
                            hint: "ពណ៌រថយន្ត",
                            controller: v.color,
                          ),
                          oneInput(
                            label: "ឆ្នាំផលិត",
                            hint: "ឆ្នាំផលិត",
                            controller: v.year,
                          ),
                          const Divider(height: 24),
                        ],
                      );
                    }),

                    // ✅ ATTACHMENTS
                    uploadMultiAttachment(),
                    uploadCameraAttachment(),

                    // ✅ BUTTONS (inside scroll => can see full form)
                    bottom(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),

          // ✅ This makes sure the scroll has space after overlap
          const SizedBox(height: 60),
        ],
      ),
    ),
  );
}
  // ----------------------------
  // Work dropdown widgets
  // ----------------------------
  Widget _ddGeneralDepartment() {
    return fieldBlock(
      label: "ក្រសួង/ស្ថាប័ន",
      child: DropdownButtonFormField<GeneralDepartmentItem>(
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
    );
  }

  Widget _ddDepartment() {
    return fieldBlock(
      label: "នាយកដ្ឋាន/អង្គភាព",
      child: DropdownButtonFormField<DepartmentItem>(
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
    );
  }

  Widget _ddBurau() {
    return fieldBlock(
      label: "ការិយាល័យ",
      child: DropdownButtonFormField<BurauItem>(
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
    );
  }

  Widget _ddPosition() {
    return fieldBlock(
      label: "តួនាទី",
      child: DropdownButtonFormField<PositionItem>(
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
    );
  }

  // ----------------------------
  // oneInput
  // ----------------------------
  Widget oneInput({
    required String label,
    required String hint,
    required TextEditingController controller,
  }) {
    return textFieldBlock(label: label, hint: hint, controller: controller);
  }

  // ----------------------------
  // Plate UI
  // ----------------------------
  Widget plateRow(_VehicleForm v) {
    final isMoto = v.vehicleType == "MOTORBIKE";
    final items = isMoto ? motoPlateTypes : plateCategory;

    final currentType = isMoto ? v.motoPlateType : v.carPlateType;
    final currentSubcategory =
        isMoto ? v.motoPlateSubcategory : v.carPlateSubcategory;

    final subcategoryList = currentType.isNotEmpty
        ? (items.firstWhere((t) => t["key"] == currentType)["subcategory"]
            as List<String>)
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        fieldBlock(
          label: isMoto ? "ប្រភេទស្លាកលេខម៉ូតូ" : "ប្រភេទស្លាកលេខរថយន្ត",
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
                  v.motoPlateSubcategory = null;
                } else {
                  v.carPlateType = x;
                  v.carPlateSubcategory = null;
                }

                v.plate.text = _formatPlateLive(v, v.plate.text);
              });
            },
          ),
        ),
        fieldBlock(
          label: "ក្រុមផ្លាកលេខ",
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: (currentSubcategory != null &&
                    subcategoryList.contains(currentSubcategory))
                ? currentSubcategory
                : null,
            decoration: inputDecoration("ជ្រើសក្រុមផ្លាកលេខ"),
            items: subcategoryList
                .map((sub) => DropdownMenuItem<String>(
                      value: sub,
                      child: Text(
                        subcategoryLabel(sub),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                if (isMoto) {
                  v.motoPlateSubcategory = value;
                } else {
                  v.carPlateSubcategory = value;
                }
              });
            },
          ),
        ),
      ],
    );
  }
  Widget plateBox({
    required String label,
    required String code,
    required String keyText,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w500, color: Colors.blue),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            code,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 6),
          Container(height: 2, color: Colors.blue),
          const SizedBox(height: 6),
          Text(
            keyText,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
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
                      overflow: TextOverflow.ellipsis),
                ),
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
          Text(selfieRequired ? "ថតរូប Selfie (ចាំបាច់)" : "ថតរូប Selfie (ជាជម្រើស)"),
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
                  color: cameraError != null ? Colors.red : Colors.grey.shade400,
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
                  child: Text(cameraFileName!, overflow: TextOverflow.ellipsis),
                ),
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
      height: 340,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color(0xFF06175F),
      ),
      child: Column(
        children: [
          SizedBox(height: 55),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Image.asset(
                    'assets/img/about-moi-logo.png',
                    height: 90,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ក្រសួងមហាផ្ទៃ',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xffDFB73B),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Ministry of Interior',
                    style: TextStyle(
                      fontSize: 18,
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
            "ទម្រង់ការស្នើរសំុបំពេញបែបបទចេញចូល​",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,color: Colors.white),
          ),
          SizedBox(height: 5),
          Text(
            "ទីស្តីការក្រសួងមហាផ្ទៃ",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,color: Colors.white),
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

            // ✅ reset duration dropdown
            selectedDurationDays = null;
            durationError = null;

            if (!(v == "INSIDE_OFFICER" || v == "OUTSIDE_OFFICER")) {
              idNumberController.clear();
            }

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

            // ✅ Keep these clears (no date picker used anymore)
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
        child: Row(
          children: [
            // Expanded(
            //   child: SizedBox(
            //     height: 48,
            //     child: OutlinedButton(
            //       style: OutlinedButton.styleFrom(
            //         side: const BorderSide(color: Color(0xFFFFCA28)),
            //         shape: RoundedRectangleBorder(
            //           borderRadius: BorderRadius.circular(15),
            //         ),
            //       ),
            //       onPressed: () {
            //         setState(() => vehicles.add(_VehicleForm()));
            //       },
            //       child: Row(
            //         mainAxisSize: MainAxisSize.min,
            //         children: const [
            //           Icon(Icons.add, color: Color(0xFFFFCA28), size: 20),
            //           SizedBox(width: 6),
            //           Text(
            //             "បន្ថែមរថយន្ត",
            //             style:
            //                 TextStyle(fontSize: 16, color: Color(0xFFFFCA28)),
            //           ),
            //         ],
            //       ),
            //     ),
            //   ),
            // ),
            // const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06175F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: submitRegister,
                  child: const Text(
                    "ដាក់ស្នើ",
                    style: TextStyle(fontSize: 18, color: Colors.white,fontWeight: FontWeight.bold),
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