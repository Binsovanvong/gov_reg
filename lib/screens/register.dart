import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gov_reg/api/api.dart';
import 'package:gov_reg/models/parking_card.dart';
import 'package:gov_reg/routes/approute.dart';
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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const List<String> allowedUserTypes = [
    "SECRETARY",
    "DEPUTY_SECRETARY",
    "INSIDE_OFFICER",
    "OUTSIDE_OFFICER",
    "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER",
    "GUEST",
  ];

  static const List<String> provinces = [
    "ភ្នំពេញ",
    "បន្ទាយមានជ័យ",
    "បាត់ដំបង",
    "កំពង់ចាម",
    "កំពង់ឆ្នាំង",
    "កំពង់ស្ពឺ",
    "កំពង់ធំ",
    "កំពត",
    "កណ្ដាល",
    "កោះកុង",
    "ក្រចេះ",
    "មណ្ឌលគិរី",
    "ឧត្តរមានជ័យ",
    "ប៉ៃលិន",
    "ព្រះសីហនុ",
    "ព្រះវិហារ",
    "ពោធិ៍សាត់",
    "ព្រៃវែង",
    "រតនគិរី",
    "សៀមរាប",
    "ស្ទឹងត្រែង",
    "ស្វាយរៀង",
    "តាកែវ",
    "ត្បូងឃ្មុំ",
    "កែប",
  ];
  final List<String> madeYears = List.generate(
    2028 - 1980 + 1,
    (index) => (1980 + index).toString(),
  ).reversed.toList();
  String _userType = "GUEST";
  bool isLoading = false;
  bool _dropdownSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _loadWorkDropdownsIfNeeded(userTypeOverride: _userType);
    _initDefaultSubcategories();
  }

  Future<void> _initDefaultSubcategories() async {
    final carSubs = await Api.fetchPlateSubCategories("REGULAR");
    final motoSubs = await Api.fetchPlateSubCategories("REGULAR");
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

  int? _lastRequestDurationDays;
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

  bool get isGuest => _userType == "GUEST";
  bool get isInsideOfficer => _userType == "INSIDE_OFFICER";
  bool get isOutsideOfficer => _userType == "OUTSIDE_OFFICER";
  bool get isOfficer => isInsideOfficer || isOutsideOfficer;
  bool get isNational =>
      _userType == "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER";

  static const bool showWorkFieldsForGuest = true;

  bool get showIdNumber => isOfficer;
  bool get showWorkFields => isOfficer || (isGuest && showWorkFieldsForGuest);
  bool get showProvinceCity => isNational;
  bool get useDurationDays => isNational || isGuest;
  bool get selfieRequired => isGuest;
  bool get useWorkDropdown => isOfficer;
  bool get showReasonField =>
      _userType == "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER" ||
      _userType == "GUEST";

  void _syncWorkControllersFromDropdownIfNeeded() {
    if (!useWorkDropdown) return;
    if (selectedGD != null) ministryController.text = selectedGD!.name;
    if (selectedDept != null) departmentController.text = selectedDept!.name;
    if (selectedBurau != null) officeController.text = selectedBurau!.name;
    if (selectedPos != null) positionController.text = selectedPos!.name;
  }

  String getPlateKey(_VehicleForm v) {
    return v.vehicleType == "MOTORBIKE" ? v.motoPlateType : v.carPlateType;
  }

  String? getSubcategoryKey(_VehicleForm v) {
    final code = v.vehicleType == "MOTORBIKE"
        ? v.motoPlateSubcategory
        : v.carPlateSubcategory;
    return (code != null && code.trim().isNotEmpty) ? code : null;
  }

  String _normalizePlate(String s) =>
      s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  String _fmtDmy(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";

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

    if (ruleKey.contains("CAMBODIA")) {
      return upper.replaceAll(RegExp(r'[^A-Z0-9.]'), '');
    }

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
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }),
    ];
  }

  void _snack(
    String msg, {
    bool isError = true,
    IconData? icon,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final bgColor =
        isError ? const Color(0xFFE53935) : const Color(0xFF1E8E3E);
    final glowColor =
        isError ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9);
    final usedIcon = icon ??
        (isError ? Icons.error_rounded : Icons.check_circle_rounded);

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
        padding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                bgColor,
                Color.lerp(bgColor, Colors.black, 0.08)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: bgColor.withOpacity(0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: glowColor.withOpacity(0.7),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    usedIcon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    msg,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => messenger.hideCurrentSnackBar(),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
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
    );
  }

  void _snackError(String msg) {
    _snack(msg, isError: true, icon: Icons.error_rounded);
  }

  void _snackSuccess(String msg) {
    _snack(msg, isError: false, icon: Icons.check_circle_rounded);
  }

  String _mapBackendErrorMessage(String raw) {
    final msg = raw.trim();
    final lower = msg.toLowerCase();
    if (lower.contains("request not found") || lower.contains("not found")) {
      return "រកមិនឃើញទិន្នន័យសំណើ";
    }
    if (lower.contains("duplicate") ||
        lower.contains("already exists") ||
        lower.contains("already exist") ||
        lower.contains("already registered") ||
        lower.contains("already used") ||
        lower.contains("already")) {
      if (lower.contains("plate")) {
        return "ផ្លាកលេខនេះមានរួចហើយ";
      }
      if (lower.contains("phone")) {
        return "លេខទូរស័ព្ទនេះមានរួចហើយ";
      }
      if (lower.contains("police")) {
        return "អត្តលេខនេះមានរួចហើយ";
      }
      if (lower.contains("code")) {
        return "លេខកូដនេះមានរួចហើយ";
      }
      return "ទិន្នន័យនេះមានរួចហើយ";
    }
    if (msg.isEmpty) {
      return "មានបញ្ហាក្នុងការដាក់ស្នើ";
    }

    return msg;
  }

  Future<void> _loadWorkDropdownsIfNeeded({String? userTypeOverride}) async {
    final type = userTypeOverride ?? _userType;
    if (type != "INSIDE_OFFICER" && type != "OUTSIDE_OFFICER") return;

    setState(() => dropdownLoading = true);
    try {
      final gds = await Api.fetchGeneralDepartments();
      final buraus = await Api.fetchBuraus();
      final positions = await Api.fetchPositions();
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
      final deps = await Api.fetchDepartmentsByGeneralDepartment(gd.id);
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

  Future<void> _doSearch() async {
  final query = searchController.text.trim();
  if (query.isEmpty) return;

  setState(() => isLoading = true);

  try {
    final results = await Api.searchParkingCardRequest(query);

    if (!mounted) return;

    if (results.isEmpty) {
      _snack("រកមិនឃើញទិន្នន័យសំណើ");
      return;
    }

    final fixedResults = results.map((res) {
      return ParkingCardRequestResponseDTO(
        id: res.id,
        name: res.name,
        code: res.code,
        token: res.token,
        userType: res.userType,
        organization: (res.organization != null && res.organization!.trim().isNotEmpty)
            ? res.organization
            : res.generalDepartmentText,
        position: (res.position != null && res.position!.trim().isNotEmpty)
            ? res.position
            : res.positionText,
        policeId: res.policeId,
        department: (res.department != null && res.department!.trim().isNotEmpty)
            ? res.department
            : res.departmentText,
        bureau: (res.bureau != null && res.bureau!.trim().isNotEmpty)
            ? res.bureau
            : res.bureauText,
        phone: res.phone,
        vehicles: res.vehicles,
        attachments: res.attachments,
        requestDate: res.requestDate,
        requestAtDate: res.requestAtDate,
        parkingRequestStatus: res.parkingRequestStatus,
        positionText: res.positionText,
        generalDepartment: res.generalDepartment,
        generalDepartmentText: res.generalDepartmentText,
        departmentText: res.departmentText,
        bureauText: res.bureauText,
        reason: res.reason,
        provinceCity: res.provinceCity,
        createdAt: res.createdAt,
      );
    }).toList();

    Navigator.pushNamed(
      context,
      Approute.verifySuccessScreen,
      arguments: {
        "response": fixedResults.first,
        "allResults": fixedResults,
        "selfieBytes": null,
        "selfiePath": null,
      },
    );
  } on ApiException catch (e) {
    _snack(e.message);
  } catch (e) {
    _snack(e.toString());
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}

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
      maxHeight: 2000,
    );
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
        decoded = img.copyResize(
          decoded!,
          width: (decoded.width * 1.1).toInt(),
          height: (decoded.height * 1.1).toInt(),
        );
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

  Widget fieldBlock({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
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
    int maxLines = 1,
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
        maxLines: maxLines,
        minLines: maxLines > 1 ? maxLines : 1,
        buildCounter: (
          context, {
          required currentLength,
          required isFocused,
          maxLength,
        }) =>
            null,
        decoration: inputDecoration(hint).copyWith(suffixIcon: suffixIcon),
      ),
    );
  }

  Widget oneInput({
    required String label,
    required String hint,
    required TextEditingController controller,
  }) =>
      textFieldBlock(label: label, hint: hint, controller: controller);

  Widget _modernSelectField({
    required String label,
    required String placeholder,
    required String? value,
    required VoidCallback onTap,
    IconData icon = Icons.keyboard_arrow_down_rounded,
    bool isLoading = false,
  }) {
    final hasValue = value != null && value.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: isLoading ? null : onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Colors.white, Color(0xFFF7F9FC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: hasValue
                        ? const Color(0xFF06175F).withOpacity(0.22)
                        : Colors.grey.shade300,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF06175F).withOpacity(0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF06175F).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasValue
                            ? Icons.check_circle_rounded
                            : Icons.tune_rounded,
                        size: 20,
                        color: const Color(0xFF06175F),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasValue ? value : placeholder,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.3,
                          fontWeight:
                              hasValue ? FontWeight.w600 : FontWeight.w500,
                          color: hasValue
                              ? const Color(0xFF111827)
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (isLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      AnimatedRotation(
                        turns: _dropdownSheetOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(
                          icon,
                          size: 24,
                          color: const Color(0xFF06175F),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSearchableSelector<T>({
    required String title,
    required List<T> items,
    required String Function(T) labelBuilder,
    required void Function(T) onSelected,
    String searchHint = "ស្វែងរក...",
  }) async {
    setState(() => _dropdownSheetOpen = true);

    final TextEditingController searchCtrl = TextEditingController();
    List<T> filtered = List<T>.from(items);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void runFilter(String q) {
              final query = q.trim().toLowerCase();
              setModalState(() {
                filtered = items.where((item) {
                  return labelBuilder(item).toLowerCase().contains(query);
                }).toList();
              });
            }

            return SafeArea(
              child: DraggableScrollableSheet(
                initialChildSize: 0.78,
                minChildSize: 0.45,
                maxChildSize: 0.92,
                expand: false,
                builder: (_, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 46,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => Navigator.pop(ctx),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.close_rounded),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: TextField(
                            controller: searchCtrl,
                            onChanged: runFilter,
                            decoration: InputDecoration(
                              hintText: searchHint,
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_off_rounded,
                                        size: 42,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        "រកមិនឃើញទិន្នន័យ",
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, i) {
                                    final item = filtered[i];
                                    final label = labelBuilder(item);

                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(18),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          onSelected(item);
                                        },
                                        child: Ink(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            border: Border.all(
                                              color: Colors.grey.shade200,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.03),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 38,
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF06175F)
                                                      .withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                  Icons.layers_rounded,
                                                  color: Color(0xFF06175F),
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  label,
                                                  style: const TextStyle(
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ),
                                              const Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    searchCtrl.dispose();
    if (mounted) {
      setState(() => _dropdownSheetOpen = false);
    }
  }

  Future<void> _showSimpleStringSelector({
    required String title,
    required List<String> items,
    required void Function(String) onSelected,
    String searchHint = "ស្វែងរក...",
  }) async {
    await _showSearchableSelector<String>(
      title: title,
      items: items,
      labelBuilder: (x) => x,
      onSelected: onSelected,
      searchHint: searchHint,
    );
  }

  Widget _durationChips() {
    return fieldBlock(
      label: "រយៈពេលស្នើរ (១-៧ ថ្ងៃ)",
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: durationError != null ? Colors.red : Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(7, (i) {
            final day = i + 1;
            final selected = selectedDurationDays == day;
            return ChoiceChip(
              label: Text("$day ថ្ងៃ"),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  selectedDurationDays = day;
                  durationError = null;
                });
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              selectedColor: const Color(0xFF06175F),
              backgroundColor: const Color(0xFFF3F4F6),
              labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xFF111827),
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(
                color:
                    selected ? const Color(0xFF06175F) : Colors.grey.shade300,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _ddGeneralDepartment() => _modernSelectField(
        label: "ក្រសួង/ស្ថាប័ន",
        placeholder: "ជ្រើសក្រសួង/ស្ថាប័ន",
        value: selectedGD?.name,
        isLoading: dropdownLoading,
        onTap: () async {
          if (gdList.isEmpty) {
            _snack("មិនមានទិន្នន័យក្រសួង/ស្ថាប័ន");
            return;
          }
          await _showSearchableSelector<GeneralDepartmentItem>(
            title: "ជ្រើសក្រសួង/ស្ថាប័ន",
            items: gdList,
            labelBuilder: (x) => x.name,
            onSelected: (x) => onSelectGD(x),
            searchHint: "ស្វែងរកក្រសួង/ស្ថាប័ន",
          );
        },
      );

  Widget _ddDepartment() => _modernSelectField(
        label: "នាយកដ្ឋាន/អង្គភាព",
        placeholder: "ជ្រើសនាយកដ្ឋាន/អង្គភាព",
        value: selectedDept?.name,
        isLoading: dropdownLoading,
        onTap: () async {
          if (selectedGD == null) {
            _snack("សូមជ្រើសក្រសួង/ស្ថាប័នជាមុន");
            return;
          }
          if (deptList.isEmpty) {
            _snack("មិនមានទិន្នន័យនាយកដ្ឋាន/អង្គភាព");
            return;
          }
          await _showSearchableSelector<DepartmentItem>(
            title: "ជ្រើសនាយកដ្ឋាន/អង្គភាព",
            items: deptList,
            labelBuilder: (x) => x.name,
            onSelected: (x) => onSelectDept(x),
            searchHint: "ស្វែងរកនាយកដ្ឋាន/អង្គភាព",
          );
        },
      );

  Widget _ddBurau() => _modernSelectField(
        label: "ការិយាល័យ",
        placeholder: "ជ្រើសការិយាល័យ",
        value: selectedBurau?.name,
        isLoading: dropdownLoading,
        onTap: () async {
          if (selectedDept == null) {
            _snack("សូមជ្រើសនាយកដ្ឋាន/អង្គភាពជាមុន");
            return;
          }
          if (burauFiltered.isEmpty) {
            _snack("មិនមានទិន្នន័យការិយាល័យ");
            return;
          }
          await _showSearchableSelector<BurauItem>(
            title: "ជ្រើសការិយាល័យ",
            items: burauFiltered,
            labelBuilder: (x) => x.name,
            onSelected: (x) => onSelectBurau(x),
            searchHint: "ស្វែងរកការិយាល័យ",
          );
        },
      );

  Widget _ddPosition() => _modernSelectField(
        label: "តួនាទី",
        placeholder: "ជ្រើសតួនាទី",
        value: selectedPos?.name,
        isLoading: dropdownLoading,
        onTap: () async {
          if (posList.isEmpty) {
            _snack("មិនមានទិន្នន័យតួនាទី");
            return;
          }
          await _showSearchableSelector<PositionItem>(
            title: "ជ្រើសតួនាទី",
            items: posList,
            labelBuilder: (x) => x.name,
            onSelected: (x) => onSelectPosition(x),
            searchHint: "ស្វែងរកតួនាទី",
          );
        },
      );

  Widget _ddProvinceCity() => _modernSelectField(
        label: "ខេត្ត/រាជធានី",
        placeholder: "ជ្រើសខេត្ត/រាជធានី",
        value:
            provinceCityController.text.isEmpty ? null : provinceCityController.text,
        onTap: () async {
          await _showSimpleStringSelector(
            title: "ជ្រើសខេត្ត/រាជធានី",
            items: provinces,
            onSelected: (value) {
              setState(() {
                provinceCityController.text = value;
              });
            },
            searchHint: "ស្វែងរកខេត្ត/រាជធានី",
          );
        },
      );

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

    Future<void> handleUserTypeChange(String v) async {
      setState(() {
        _userType = v;
        selectedDurationDays = null;
        durationError = null;

        if (!(v == "INSIDE_OFFICER" || v == "OUTSIDE_OFFICER")) {
          idNumberController.clear();
        }

        final shouldShowWork = v == "INSIDE_OFFICER" ||
            v == "OUTSIDE_OFFICER" ||
            (v == "GUEST" && showWorkFieldsForGuest);

        if (!shouldShowWork) {
          ministryController.clear();
          departmentController.clear();
          officeController.clear();
          positionController.clear();
        }

        if (v != "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER") {
          provinceCityController.clear();
        }

        if (v != "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER" &&
            v != "GUEST") {
          reasonController.clear();
        }

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
    }

    return _modernSelectField(
      label: "ប្រភេទអ្នកប្រើប្រាស់",
      placeholder: "ជ្រើសប្រភេទអ្នកប្រើប្រាស់",
      value: labelOf(_userType),
      onTap: () async {
        await _showSearchableSelector<String>(
          title: "ជ្រើសប្រភេទអ្នកប្រើប្រាស់",
          items: allowedUserTypes,
          labelBuilder: labelOf,
          onSelected: (v) => handleUserTypeChange(v),
          searchHint: "ស្វែងរកប្រភេទអ្នកប្រើប្រាស់",
        );
      },
    );
  }

  Widget plateRow(_VehicleForm v) {
    final isMoto = v.vehicleType == "MOTORBIKE";
    final currentType = isMoto ? v.motoPlateType : v.carPlateType;
    final currentSubcategoryCode =
        isMoto ? v.motoPlateSubcategory : v.carPlateSubcategory;
    final subcategories = isMoto ? v.motoSubcategories : v.carSubcategories;

    String typeLabel(String key) {
      final source = isMoto ? motoPlateTypes : plateCategory;
      try {
        return source.firstWhere((t) => t["key"] == key)["label"] as String;
      } catch (_) {
        return key;
      }
    }

    String? currentSubcategoryName() {
      if (currentSubcategoryCode == null) return null;
      try {
        return subcategories
            .firstWhere((s) => s.code == currentSubcategoryCode)
            .name;
      } catch (_) {
        return currentSubcategoryCode;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _modernSelectField(
          label: isMoto ? "ប្រភេទស្លាកលេខម៉ូតូ" : "ប្រភេទស្លាកលេខរថយន្ត",
          placeholder: "ប្រភេទស្លាក",
          value: typeLabel(currentType),
          onTap: () async {
            final source = isMoto ? motoPlateTypes : plateCategory;
            await _showSearchableSelector<Map<String, dynamic>>(
              title: isMoto
                  ? "ជ្រើសប្រភេទស្លាកលេខម៉ូតូ"
                  : "ជ្រើសប្រភេទស្លាកលេខរថយន្ត",
              items: source,
              labelBuilder: (t) => t["label"] as String,
              onSelected: (selected) async {
                final x = selected["key"] as String;
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

                final subs = await Api.fetchPlateSubCategories(x);
                if (!mounted) return;
                setState(() {
                  if (isMoto) {
                    v.motoSubcategories = subs;
                  } else {
                    v.carSubcategories = subs;
                  }
                });
              },
              searchHint: "ស្វែងរកប្រភេទស្លាក",
            );
          },
        ),
        _modernSelectField(
          label: "ក្រុមផ្លាកលេខ",
          placeholder:
              subcategories.isEmpty ? "កំពុងដំណើរការ..." : "ជ្រើសក្រុមផ្លាកលេខ",
          value: currentSubcategoryName(),
          isLoading: subcategories.isEmpty,
          onTap: () async {
            if (subcategories.isEmpty) return;
            await _showSearchableSelector<PlateSubCategoryItem>(
              title: "ជ្រើសក្រុមផ្លាកលេខ",
              items: subcategories,
              labelBuilder: (sub) => sub.name,
              onSelected: (selected) {
                setState(() {
                  if (isMoto) {
                    v.motoPlateSubcategory = selected.code;
                  } else {
                    v.carPlateSubcategory = selected.code;
                  }
                });
              },
              searchHint: "ស្វែងរកក្រុមផ្លាកលេខ",
            );
          },
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
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.blue,
            ),
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
            textAlign: TextAlign.center,
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

  Widget _uploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
    required Widget bottomContent,
    bool isError = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Colors.white,
            gradient.last.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color:
              isError ? Colors.red.shade300 : gradient.last.withOpacity(0.22),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradient),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: gradient.last.withOpacity(0.24),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12.8,
                              height: 1.35,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: gradient.last.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: gradient.last,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withOpacity(0.75),
                    border: Border.all(
                      color: isError
                          ? Colors.red.shade200
                          : gradient.last.withOpacity(0.12),
                    ),
                  ),
                  child: bottomContent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _attachmentBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget uploadMultiAttachment() {
    return _uploadCard(
      title: isGuest ? "ឯកសាររថយន្ត" : "ឯកសារភ្ជាប់",
      subtitle: isGuest
          ? "សូមភ្ជាប់ឯកសារពាក់ព័ន្ធនឹងយានយន្ត"
          : "អាចភ្ជាប់ឯកសារបន្ថែមបាន",
      icon: Icons.cloud_upload_rounded,
      gradient: const [Color(0xFF0EA5E9), Color(0xFF2563EB)],
      onTap: pickAttachFiles,
      isError: attachFilesError != null,
      bottomContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "***សូមភ្ជាប់ឯកសារភ្ជាប់ដូចខាងក្រោម/ចាំបាច់\n"
            "- បណ្ណសម្គាល់យានយន្ត/កាតគ្រី\n"
            "- បណ្ណបើកបរ\n"
            "- បណ្ណសម្គាល់ម្ចាស់យានយន្ត ឬឯកសារពាក់ព័ន្ធផ្សេងៗ\n"
            "- អត្តសញ្ញាណប័ណ្ណសញ្ជាតិខ្មែរ",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB42318),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  "ចុចដើម្បីជ្រើសឯកសារ",
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              _attachmentBadge(
                icon: Icons.folder_zip_rounded,
                text: "${attachFiles.length}/$maxFiles",
                color: const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _attachmentBadge(
                icon: Icons.image_rounded,
                text: "PNG / JPG",
                color: const Color(0xFF0284C7),
              ),
              _attachmentBadge(
                icon: Icons.picture_as_pdf_rounded,
                text: "PDF",
                color: const Color(0xFFDC2626),
              ),
              _attachmentBadge(
                icon: Icons.scale_rounded,
                text: "≤ 5MB",
                color: const Color(0xFF7C3AED),
              ),
            ],
          ),
          if (attachFileNames.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              "ឯកសារដែលបានជ្រើស",
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(attachFileNames.length, (i) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        attachFileNames[i].toLowerCase().endsWith(".pdf")
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_rounded,
                        color: attachFileNames[i].toLowerCase().endsWith(".pdf")
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        attachFileNames[i],
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.red,
                      ),
                      onPressed: () => removeAttachFileAt(i),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (attachFilesError != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.red, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    attachFilesError!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
    Widget _ddMadeYear(_VehicleForm v) => _modernSelectField(
        label: "ឆ្នាំផលិត",
        placeholder: "ជ្រើសឆ្នាំផលិត",
        value: v.year.text.isEmpty ? null : v.year.text,
        onTap: () async {
          await _showSimpleStringSelector(
            title: "ជ្រើសឆ្នាំផលិត",
            items: madeYears,
            onSelected: (value) {
              setState(() {
                v.year.text = value;
              });
            },
            searchHint: "ស្វែងរកឆ្នាំផលិត",
          );
        },
      );
  Widget uploadCameraAttachment() {
    return _uploadCard(
      title: selfieRequired ? "Selfie ផ្ទៀងផ្ទាត់" : "Selfie",
      subtitle: selfieRequired
          ? "ថតរូប Selfie សម្រាប់ការផ្ទៀងផ្ទាត់"
          : "អាចថតរូប Selfie បន្ថែមបាន",
      icon: Icons.camera_alt_rounded,
      gradient: const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
      onTap: pickCameraImage,
      isError: cameraError != null,
      bottomContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  selfieRequired ? "ចុចដើម្បីថតរូប (ចាំបាច់)" : "ចុចដើម្បីថតរូប",
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              _attachmentBadge(
                icon: selfieRequired
                    ? Icons.verified_user_rounded
                    : Icons.camera_front_rounded,
                text: selfieRequired ? "Required" : "Optional",
                color: selfieRequired
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF7C3AED),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _attachmentBadge(
                icon: Icons.photo_camera_front_rounded,
                text: "Camera",
                color: const Color(0xFF8B5CF6),
              ),
              _attachmentBadge(
                icon: Icons.scale_rounded,
                text: "≤ 5MB",
                color: const Color(0xFFEC4899),
              ),
              _attachmentBadge(
                icon: Icons.high_quality_rounded,
                text: "≥ 150KB",
                color: const Color(0xFF7C3AED),
              ),
            ],
          ),
          if (cameraFileName != null) ...[
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF4FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9D5FF)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.face_retouching_natural_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      cameraFileName!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.red,
                    ),
                    onPressed: clearCamera,
                  ),
                ],
              ),
            ),
          ],
          if (cameraError != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.red, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    cameraError!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 340,
      width: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/img/bgc.png'),
          fit: BoxFit.cover, 
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 55),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Image.asset('assets/img/about-moi-logo.png',
                      height: 90),
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ក្រសួងមហាផ្ទៃ',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE0A428),
                      fontFamily: 'khmer moul light',
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Ministry of Interior',
                    style: TextStyle(
                      fontSize: 22,
                      color: Color(0xFFE0A428),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'khmer moul light',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "ទម្រង់ការស្នើរសំុបំពេញបែបបទចេញចូល​",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "ទីស្តីការក្រសួងមហាផ្ទៃ",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
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

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF06175F), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.red, width: 1.4),
      ),
    );
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
    final phone = phoneController.text.trim();
    if (phone.isEmpty) {
      _snack("សូមបញ្ចូលលេខទូរស័ព្ទ");
      return false;
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(phone)) {
      _snack("លេខទូរស័ព្ទត្រូវមានតែលេខ");
      return false;
    }
    if (phone.length != 9 && phone.length != 10) {
      _snack("លេខទូរស័ព្ទត្រូវមាន ៩ ឬ ១០ ខ្ទង់");
      return false;
    }
    if (showReasonField && reasonController.text.trim().isEmpty) {
      _snack("សូមបញ្ចូលមូលហេតុ");
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
      _snack("សូមជ្រើសខេត្ត/រាជធានី");
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

  Future<void> submitRegister() async {
    debugPrint("SUBMIT pressed");
    _syncWorkControllersFromDropdownIfNeeded();

    if (!validateForm()) return;

    setState(() => isLoading = true);

    try {
      final nowRaw = DateTime.now();
      final now = DateTime(nowRaw.year, nowRaw.month, nowRaw.day);

      const fixed365Users = [
        "SECRETARY",
        "DEPUTY_SECRETARY",
        "INSIDE_OFFICER",
        "OUTSIDE_OFFICER",
      ];

      const durationUsers = [
        "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER",
        "GUEST",
      ];

      if (fixed365Users.contains(_userType)) {
        _lastRequestDurationDays = 365;
        _lastRequestAtDateStr = _fmtDmy(now);
      } else if (durationUsers.contains(_userType)) {
        _lastRequestDurationDays = selectedDurationDays ?? 1;
        _lastRequestAtDateStr = _fmtDmy(now);
      } else {
        _lastRequestDurationDays = 365;
        _lastRequestAtDateStr = _fmtDmy(now);
      }

      String fill(String s) => s.isEmpty ? "-" : s;

      final requestDto = ParkingCardRequestRequestDTO(
        reason: reasonController.text.trim().isEmpty
            ? "Parking card request"
            : reasonController.text.trim(),
        requestDate: _lastRequestDurationDays,
        requestAtDate: _lastRequestAtDateStr,
        user: UserRequestDTO(
          name: fullNameController.text.trim(),
          phone: phoneController.text.trim(),
          userType: UserTypeX.fromString(_userType),
          workingInfo: WorkingInfoDTO(
            policeId: showIdNumber ? idNumberController.text.trim() : "",
            generalDepartmentText:
                showWorkFields ? fill(ministryController.text.trim()) : "",
            departmentText:
                showWorkFields ? fill(departmentController.text.trim()) : "",
            bureauText: showWorkFields ? fill(officeController.text.trim()) : "",
            positionText:
                showWorkFields ? fill(positionController.text.trim()) : "",
            generalDepartment: useWorkDropdown ? (selectedGD?.id ?? 0) : 0,
            department: useWorkDropdown ? (selectedDept?.id ?? 0) : 0,
            bureau: useWorkDropdown ? (selectedBurau?.id ?? 0) : 0,
            position: useWorkDropdown ? (selectedPos?.id ?? 0) : 0,
            provinceCity:
                showProvinceCity ? provinceCityController.text.trim() : "",
          ),
        ),
        vehicles: vehicles
            .map(
              (v) => VehicleDTO(
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
              ),
            )
            .toList(),
      );

      debugPrint("DTO SENT = ${jsonEncode(requestDto.toJson())}");
      debugPrint("USER TYPE = $_userType");
      debugPrint("REQUEST AT DATE = $_lastRequestAtDateStr");
      debugPrint("REQUEST DATE = $_lastRequestDurationDays");

      final ParkingCardRequestResponseDTO res =
          await Api.createParkingCardRequest(
        CreateParkingCardPayload(
          dto: requestDto,
          vehicleFiles: attachFiles,
          vehicleFileNames: attachFileNames,
          selfieFile: cameraFile,
          selfieFileName: cameraFileName,
        ),
      );

      if (!mounted) return;

      Uint8List? selfieBytes;
      if (cameraFile != null) {
        selfieBytes = await cameraFile!.readAsBytes();
      }

      final filledRes = ParkingCardRequestResponseDTO(
        id: res.id,
        name: res.name ?? fullNameController.text.trim(),
        code: res.code,
        token: res.token,
        userType: res.userType ?? UserTypeX.fromString(_userType),
        organization: res.organization ?? ministryController.text.trim(),
        position: res.position ?? positionController.text.trim(),
        policeId: res.policeId ?? idNumberController.text.trim(),
        department: res.department ?? departmentController.text.trim(),
        bureau: res.bureau ?? officeController.text.trim(),
        phone: res.phone ?? phoneController.text.trim(),
        vehicles: res.vehicles,
        attachments: res.attachments,
        requestDate: _lastRequestDurationDays,
        requestAtDate: _lastRequestAtDateStr,
        parkingRequestStatus: res.parkingRequestStatus,
        positionText: res.positionText ?? positionController.text.trim(),
        generalDepartment: res.generalDepartment,
        generalDepartmentText:
            res.generalDepartmentText ?? ministryController.text.trim(),
        departmentText: res.departmentText ?? departmentController.text.trim(),
        bureauText: res.bureauText ?? officeController.text.trim(),
        reason: res.reason ?? reasonController.text.trim(),
        provinceCity: res.provinceCity ?? provinceCityController.text.trim(),
        createdAt: res.createdAt,
      );

      if (!mounted) return;

      _snackSuccess("បានដាក់ស្នើដោយជោគជ័យ");

      Navigator.pushNamed(
        context,
        Approute.verifySuccessScreen,
        arguments: {
          "response": filledRes,
          "allResults": [filledRes],
          "selfieBytes": selfieBytes,
          "selfiePath": cameraFile?.path,
        },
      );
    } on ApiException catch (e) {
      debugPrint("SUBMIT API ERROR: ${e.message}");
      if (!mounted) return;
      _snackError(_mapBackendErrorMessage(e.message));
    } catch (e, st) {
      debugPrint("SUBMIT ERROR: $e");
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      _snackError("មានបញ្ហាក្នុងការដាក់ស្នើ: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _creativeSubmitButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: isLoading ? null : submitRegister,
        child: AnimatedScale(
          scale: isLoading ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: isLoading ? 0.7 : 1,
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF06175F),
                    Color(0xFF0A2D88),
                    Color(0xFF1E3A8A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06175F).withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "ដាក់ស្នើ",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.3,
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
    searchController.dispose();
    for (final v in vehicles) {
      v.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!allowedUserTypes.contains(_userType)) _userType = "GUEST";

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          children: [
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
                        color: Colors.black12,
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: searchController,
                                decoration:
                                    inputDecoration("តាមរយះ លេខកូដ ឬលេខទូរស័ព្ទ")
                                        .copyWith(
                                  prefixIcon: const Icon(Icons.search),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 48,
                              width: 48,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _doSearch,
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
                                child: const Icon(
                                  Icons.search,
                                  size: 24,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      sectionTitle("ព័ត៌មានផ្ទាល់ខ្លួន"),
                      dropdownUserType(),
                      const SizedBox(height: 15),
                      oneInput(
                        label: "គោត្តនាម និងនាម",
                        hint: "បញ្ចូលឈ្មោះពេញ",
                        controller: fullNameController,
                      ),
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
                      if (showWorkFields) ...[
                        sectionTitle("ព័ត៌មានការងារ"),
                        if (useWorkDropdown) ...[
                          if (dropdownLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
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
                      if (showProvinceCity) _ddProvinceCity(),
                      textFieldBlock(
                        label: "លេខទូរស័ព្ទ",
                        hint: "លេខទូរស័ព្ទ",
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                      if (showReasonField)
                        textFieldBlock(
                          label: "មូលហេតុ",
                          hint: "បញ្ចូលមូលហេតុ",
                          controller: reasonController,
                          maxLines: 3,
                          keyboardType: TextInputType.multiline,
                        ),
                      if (useDurationDays) ...[
                        _durationChips(),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                          child: Text(
                            "កាលបរិច្ឆេទស្នើរ៖ ស្វ័យប្រវត្តិ ៣៦៥ ថ្ងៃ",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
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
                                horizontal: 20,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    "រថយន្ត/ម៉ូតូ #${i + 1}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (vehicles.length > 1)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => setState(() {
                                        v.dispose();
                                        vehicles.removeAt(i);
                                      }),
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
                                    onChanged: (x) async {
                                      setState(() => v.vehicleType = x!);
                                      if (v.carSubcategories.isEmpty) {
                                        final subs =
                                            await Api.fetchPlateSubCategories(
                                          v.carPlateType,
                                        );
                                        if (!mounted) return;
                                        setState(() => v.carSubcategories = subs);
                                      }
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                    value: "MOTORBIKE",
                                    groupValue: v.vehicleType,
                                    title: const Text("ម៉ូតូ"),
                                    onChanged: (x) async {
                                      setState(() => v.vehicleType = x!);
                                      if (v.motoSubcategories.isEmpty) {
                                        final subs =
                                            await Api.fetchPlateSubCategories(
                                          v.motoPlateType,
                                        );
                                        if (!mounted) return;
                                        setState(() => v.motoSubcategories = subs);
                                      }
                                    },
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
                              ),
                            ),
                            oneInput(
                              label: "ពណ៌",
                              hint: "ពណ៌រថយន្ត",
                              controller: v.color,
                            ),
                            _ddMadeYear(v),
                            const Divider(height: 24),
                          ],
                        );
                      }),
                      uploadMultiAttachment(),
                      uploadCameraAttachment(),
                      const SizedBox(height: 40),
                      _creativeSubmitButton(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
