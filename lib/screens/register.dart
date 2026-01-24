import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gov_reg/routes/approute.dart';
import 'package:http/http.dart' as http;

/// ✅ MUST be top-level (NOT inside State class)
class _VehicleForm {
  final brand = TextEditingController();
  final plate = TextEditingController();
  final color = TextEditingController();
  final year = TextEditingController();
  String vehicleType = "CAR";

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
  static const String baseUrl = "http://localhost:8080";

  static const List<String> allowedUserTypes = [
    "GUEST",
    "INSIDE_OFFICER",
    "OUTSIDE_OFFICER",
    "SECRETARY_AND_DEPUTY_SECRETARY",
    "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER",
  ];

  static const String attachmentTypeValue = "VEHICLE_DOCUMENT";

  String _userType = "GUEST";
  bool isLoading = false;

  // Officer attachment (required)
  File? attachmentFile;
  String? attachmentName;
  String? attachmentError;

  // Optional attachment for Secretary / National Admin
  File? optionalFile;
  String? optionalFileName;
  String? optionalFileError;

  // Guest attachments 2 optional files
  File? guestFile1;
  String? guestFile1Name;
  String? guestFile1Error;

  File? guestFile2;
  String? guestFile2Name;
  String? guestFile2Error;

  // Controllers
  final fullNameController = TextEditingController();
  final idNumberController = TextEditingController();
  final ministryController = TextEditingController();
  final departmentController = TextEditingController();
  final officeController = TextEditingController();
  final positionController = TextEditingController();
  final phoneController = TextEditingController();
  final requestDateController = TextEditingController();
  final provinceCityController = TextEditingController();
  final reasonController = TextEditingController();

  // Vehicles list
  final List<_VehicleForm> vehicles = [_VehicleForm()];

  // ----------------------------
  // Rules
  // ----------------------------
  bool get isGuest => _userType == "GUEST";

  bool get isInsideOfficer => _userType == "INSIDE_OFFICER";

  bool get isOutsideOfficer => _userType == "OUTSIDE_OFFICER";

  bool get isSecretary => _userType == "SECRETARY_AND_DEPUTY_SECRETARY";

  bool get isNationalAdmin =>
      _userType == "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER";

  bool get isOfficer => isInsideOfficer || isOutsideOfficer;

  // Guest shows work fields too
  static const bool showWorkFieldsForGuest = true;

  bool get showIdNumber => isOfficer;

  bool get showWorkFields => isOfficer || (isGuest && showWorkFieldsForGuest);

  bool get showProvinceCity => isNationalAdmin;

  bool get needAttachment => isOfficer;

  bool get showOptionalAttachment => isSecretary || isNationalAdmin;

  bool get showGuestTwoAttachments => isGuest;

  // ----------------------------
  // Helpers
  // ----------------------------
  String _normalizePlate(String s) =>
      s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

  bool _isExactlyNDigits(String s, int n) => _digitsOnly(s).length == n;

  final RegExp _carPlateRegex = RegExp(r'^2[A-Z]{2}-\d{4}$');
  final RegExp _motoPlateRegex = RegExp(r'^1[A-Z]{2}-\d{4}$');

  int _dateToYyyyMMddInt(String yyyyMmDd) {
    final clean = yyyyMmDd.trim().replaceAll('-', '');
    return int.tryParse(clean) ?? 0;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickFile({
    required void Function(String? err) setErr,
    required void Function(File f, String name) setPicked,
  }) async {
    setErr(null);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (file.path == null) {
      setErr("មិនអាចយកផ្លូវឯកសារបានទេ");
      return;
    }

    final f = File(file.path!);

    final bytes = await f.length();
    const maxBytes = 5 * 1024 * 1024;
    if (bytes > maxBytes) {
      setErr("ឯកសារធំពេក (≤ 5MB)");
      return;
    }

    final ext = (file.extension ?? "").toLowerCase();
    if (!['png', 'jpg', 'jpeg', 'pdf'].contains(ext)) {
      setErr("ប្រភេទឯកសារមិនត្រឹមត្រូវ");
      return;
    }

    setPicked(f, file.name);
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

    for (final v in vehicles) {
      v.dispose();
    }
    super.dispose();
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
      if (!_isExactlyNDigits(policeId, 10)) {
        _snack("អត្តលេខត្រូវមាន ១០ ខ្ទង់លេខ");
        return false;
      }
    }

    if (phoneController.text.trim().isEmpty) {
      _snack("សូមបញ្ចូលលេខទូរស័ព្ទ");
      return false;
    }

    if (requestDateController.text.trim().isEmpty) {
      _snack("សូមជ្រើសកាលបរិច្ឆេទស្នើរ");
      return false;
    }

    if (showWorkFields) {
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

      final plate = _normalizePlate(v.plate.text);
      if (plate.isEmpty) {
        _snack("សូមបញ្ចូលស្លាកលេខ (#${i + 1})");
        return false;
      }

      if (v.vehicleType == "CAR") {
        if (!_carPlateRegex.hasMatch(plate)) {
          _snack("ស្លាកលេខរថយន្ត (#${i + 1}) ត្រូវជា 2AB-1223");
          return false;
        }
      } else {
        if (!_motoPlateRegex.hasMatch(plate)) {
          _snack("ស្លាកលេខម៉ូតូ (#${i + 1}) ត្រូវជា 1AB-1223");
          return false;
        }
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

    if (needAttachment && attachmentFile == null) {
      setState(() => attachmentError = "សូមភ្ជាប់ឯកសារ");
      return false;
    }

    return true;
  }

  // ----------------------------
  // Pick files
  // ----------------------------
  Future<void> pickOfficerAttachment() async {
    await _pickFile(
      setErr: (e) => setState(() => attachmentError = e),
      setPicked: (f, name) => setState(() {
        attachmentFile = f;
        attachmentName = name;
      }),
    );
  }

  Future<void> pickOptionalAttachment() async {
    await _pickFile(
      setErr: (e) => setState(() => optionalFileError = e),
      setPicked: (f, name) => setState(() {
        optionalFile = f;
        optionalFileName = name;
      }),
    );
  }

  Future<void> pickGuest1() async {
    await _pickFile(
      setErr: (e) => setState(() => guestFile1Error = e),
      setPicked: (f, name) => setState(() {
        guestFile1 = f;
        guestFile1Name = name;
      }),
    );
  }

  Future<void> pickGuest2() async {
    await _pickFile(
      setErr: (e) => setState(() => guestFile2Error = e),
      setPicked: (f, name) => setState(() {
        guestFile2 = f;
        guestFile2Name = name;
      }),
    );
  }

  // ----------------------------
  // API (✅ FIX unsupported MediaType)
  // ----------------------------
  Future<void> createParkingCardRequest() async {
    final base = Uri.parse("$baseUrl/api/parking-card-requests");

    final hasAnyFile = attachmentFile != null ||
        optionalFile != null ||
        guestFile1 != null ||
        guestFile2 != null;

    final uri = hasAnyFile
        ? base
            .replace(queryParameters: {"attachmentTypes": attachmentTypeValue})
        : base;

    final requestDateValue =
        _dateToYyyyMMddInt(requestDateController.text.trim());

    final dto = <String, dynamic>{
      "id": 0,
      "user": {
        "name": fullNameController.text.trim(),
        "phone": phoneController.text.trim(),
        "userType": _userType,
      },
      "vehicles": vehicles.map((v) {
        return {
          "brand": v.brand.text.trim(),
          "plateNumber": _normalizePlate(v.plate.text),
          "color": v.color.text.trim(),
          "madeYear": int.tryParse(v.year.text.trim()) ?? 0,
          "vehicleType": v.vehicleType,
        };
      }).toList(),
      "requestDate": requestDateValue,
      "accessType": "ONCE",
      "parkingRequestStatus": "NEW",
      "reason": reasonController.text.trim().isEmpty
          ? "Parking card request"
          : reasonController.text.trim(),
    };

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

    final request = http.MultipartRequest("POST", uri);

    // ✅ important: let backend parse multipart normally
    request.headers["Accept"] = "application/json";

    // ✅ dto must be string field
    request.fields["dto"] = jsonEncode(dto);

    // ✅ DO NOT set MediaType for files (fix unsupported MediaType)
    Future<void> addFile(File? file, String? name) async {
      if (file == null) return;
      final filename = name ?? file.path.split('/').last;

      request.files.add(
        await http.MultipartFile.fromPath(
          "files", // ✅ backend usually expects "files"
          file.path,
          filename: filename,
        ),
      );
    }

    await addFile(attachmentFile, attachmentName);
    await addFile(optionalFile, optionalFileName);
    await addFile(guestFile1, guestFile1Name);
    await addFile(guestFile2, guestFile2Name);

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw resp.body;
    }
  }

  // ----------------------------
  // Submit
  // ----------------------------
  Future<void> submitRegister() async {
    if (!validateForm()) return;

    setState(() => isLoading = true);
    try {
      await createParkingCardRequest();
      if (!mounted) return;
      Navigator.pushNamed(context, Approute.verifySuccessScreen);
    } catch (e, st) {
      debugPrint("SUBMIT ERROR: $e");
      debugPrint("STACK: $st");

      final msg = e.toString();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $msg")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ----------------------------
  // Date picker
  // ----------------------------
  void pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (d != null) {
      requestDateController.text =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
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
                                          value: "MOTORCYCLE",
                                          groupValue: v.vehicleType,
                                          title: const Text("ម៉ូតូ"),
                                          onChanged: (x) => setState(() {
                                            if (x != null) v.vehicleType = x;
                                          }),
                                        ),
                                      ),
                                    ],
                                  ),
                                  twoInputRow(
                                    "ម៉ាក",
                                    "ស្លាកលេខ",
                                    "បញ្ចូលម៉ាក",
                                    "បញ្ចូលស្លាកលេខ",
                                    v.brand,
                                    v.plate,
                                    leftIsPlate: false,
                                    rightIsPlate: true,
                                  ),
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
                            if (needAttachment) uploadOfficerAttachment(),
                            if (showOptionalAttachment)
                              uploadOptionalAttachment(),
                            if (showGuestTwoAttachments) ...[
                              uploadGuestAttachment1(),
                              uploadGuestAttachment2(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

      // ✅ bottom fixed
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      side: const BorderSide(width: 0.5, color: Colors.grey),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      setState(() => vehicles.add(_VehicleForm()));
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Icon(Icons.add, color: Color(0xffDFB73B)),
                        const Text(
                          "បន្ថែមរថយន្ត",
                          style: TextStyle(
                              fontSize: 18, color: Color(0xffDFB73B)),
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
      ),
    );
  }

  // ----------------------------
  // Widgets
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
                        color: Color(0xffDFB73B)),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Ministry of Interior',
                    style: TextStyle(
                        fontSize: 16,
                        color: Color(0xffDFB73B),
                        fontWeight: FontWeight.bold),
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
          return "មន្រ្តីបំរើការនៅក្នុងទីស្តីការក្រសួងមហាផ្ទៃ";
        case "OUTSIDE_OFFICER":
          return "មន្រ្តីបំរើការនៅក្រៅទីស្តីការក្រសួងមហាផ្ទៃ";
        case "SECRETARY_AND_DEPUTY_SECRETARY":
          return "រដ្ឋលេខាធិការ / អនុរដ្ឋលេខាធិការ​ ក្រសួងមហាផ្ទៃ";
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
                  child: Text(labelOf(v)),
                ))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _userType = v;

            if (!(v == "INSIDE_OFFICER" || v == "OUTSIDE_OFFICER")) {
              idNumberController.clear();
            }

            final shouldShowWork = (v == "INSIDE_OFFICER" ||
                v == "OUTSIDE_OFFICER" ||
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

            if (!(v == "INSIDE_OFFICER" || v == "OUTSIDE_OFFICER")) {
              attachmentFile = null;
              attachmentName = null;
              attachmentError = null;
            }

            if (!(v == "SECRETARY_AND_DEPUTY_SECRETARY" ||
                v == "NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER")) {
              optionalFile = null;
              optionalFileName = null;
              optionalFileError = null;
            }

            if (v != "GUEST") {
              guestFile1 = null;
              guestFile1Name = null;
              guestFile1Error = null;
              guestFile2 = null;
              guestFile2Name = null;
              guestFile2Error = null;
            }
          });
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
              decoration: inputDecoration("ថ្ងៃស្នើរ")
                  .copyWith(suffixIcon: const Icon(Icons.calendar_month)),
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
            controller: controller,
            decoration: inputDecoration(hint),
          ),
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

    const plateMaxLen = 8;

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

    TextInputType kbd(bool isId) =>
        isId ? TextInputType.number : TextInputType.text;

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

  Widget uploadOfficerAttachment() {
    return _uploadBox(
      title: "ឯកសារភ្ជាប់ (ចាំបាច់)",
      onTap: pickOfficerAttachment,
      fileName: attachmentName,
      error: attachmentError,
      onClear: () => setState(() {
        attachmentFile = null;
        attachmentName = null;
        attachmentError = null;
      }),
    );
  }

  Widget uploadOptionalAttachment() {
    return _uploadBox(
      title: "ឯកសារភ្ជាប់ (ជាជម្រើស)",
      onTap: pickOptionalAttachment,
      fileName: optionalFileName,
      error: optionalFileError,
      onClear: () => setState(() {
        optionalFile = null;
        optionalFileName = null;
        optionalFileError = null;
      }),
    );
  }

  Widget uploadGuestAttachment1() {
    return _uploadBox(
      title: "ឯកសារភ្ជាប់ (Guest) 1",
      onTap: pickGuest1,
      fileName: guestFile1Name,
      error: guestFile1Error,
      onClear: () => setState(() {
        guestFile1 = null;
        guestFile1Name = null;
        guestFile1Error = null;
      }),
    );
  }

  Widget uploadGuestAttachment2() {
    return _uploadBox(
      title: "ឯកសារភ្ជាប់ (Guest) 2",
      onTap: pickGuest2,
      fileName: guestFile2Name,
      error: guestFile2Error,
      onClear: () => setState(() {
        guestFile2 = null;
        guestFile2Name = null;
        guestFile2Error = null;
      }),
    );
  }

  Widget _uploadBox({
    required String title,
    required VoidCallback onTap,
    required String? fileName,
    required String? error,
    required VoidCallback onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: error != null ? Colors.red : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: const [
                  Icon(Icons.upload_file, size: 40, color: Colors.green),
                  SizedBox(height: 10),
                  Text(
                    "អូសឯកសារដាក់ទីនេះ ឬ ចុចដើម្បីជ្រើស",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "PNG, JPG, PDF (≤ 5MB)",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          if (fileName != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: Text(fileName, overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.close), onPressed: onClear),
              ],
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                error,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
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
