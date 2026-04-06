import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gov_reg/models/parking_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────

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

// ─────────────────────────────────────────────
// Request payload for createParkingCardRequest
// ─────────────────────────────────────────────

class CreateParkingCardPayload {
  final ParkingCardRequestRequestDTO dto;
  final List<File> vehicleFiles;
  final List<String> vehicleFileNames;
  final File? selfieFile;
  final String? selfieFileName;

  const CreateParkingCardPayload({
    required this.dto,
    required this.vehicleFiles,
    required this.vehicleFileNames,
    this.selfieFile,
    this.selfieFileName,
  });
}

// ─────────────────────────────────────────────
// AppApi
// ─────────────────────────────────────────────

class Api {
  static const String baseUrl = "http://175.100.74.227:1234";

  static const String _attachmentTypeVehicle = "VEHICLE_DOCUMENT";
  static const String _attachmentTypeSelfie = "INVITATION_DOCUMENT";

  static Future<Uint8List?> fetchAttachmentBytes(String attachmentId) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/api/v1/attachments/$attachmentId"),
        headers: {"Accept": "image/*"},
      );
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }

  // ── internal GET helper ───────────────────
  static Future<http.Response> _get(Uri uri) async {
    return http.get(uri, headers: {"Accept": "application/json"});
  }

  // ─────────────────────────────────────────
  // General Departments
  // ─────────────────────────────────────────
  static Future<List<GeneralDepartmentItem>> fetchGeneralDepartments() async {
    final res = await _get(Uri.parse("$baseUrl/api/v1/general-departments"));
    if (res.statusCode != 200) {
      throw "GeneralDepartments HTTP ${res.statusCode}";
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .map((e) => GeneralDepartmentItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─────────────────────────────────────────
  // Departments by General Department
  // ─────────────────────────────────────────
  static Future<List<DepartmentItem>> fetchDepartmentsByGeneralDepartment(
      int gdId) async {
    final res = await _get(
        Uri.parse("$baseUrl/api/v1/departments/general-department/$gdId"));
    if (res.statusCode != 200) {
      throw "Departments HTTP ${res.statusCode}";
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .map((e) => DepartmentItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─────────────────────────────────────────
  // Bureaus
  // ─────────────────────────────────────────
  static Future<List<BurauItem>> fetchBuraus() async {
    final res = await _get(Uri.parse("$baseUrl/api/v1/bureaus"));
    if (res.statusCode != 200) throw "Buraus HTTP ${res.statusCode}";
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .map((e) => BurauItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─────────────────────────────────────────
  // Positions
  // ─────────────────────────────────────────
  static Future<List<PositionItem>> fetchPositions() async {
    final res = await _get(Uri.parse("$baseUrl/api/v1/positions"));
    if (res.statusCode != 200) throw "Positions HTTP ${res.statusCode}";
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .map((e) => PositionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─────────────────────────────────────────
  // Plate Sub-Categories
  // ─────────────────────────────────────────
  static Future<List<PlateSubCategoryItem>> fetchPlateSubCategories(
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

  // ─────────────────────────────────────────
  // Search Parking Card Request
  // ─────────────────────────────────────────
  static Future<List<ParkingCardRequestResponseDTO>> searchParkingCardRequest(
      String search) async {
    final uri =
        Uri.parse("$baseUrl/api/v1/parking-card-requests/search/$search");
    final res = await _get(uri);
    debugPrint("SEARCH RAW BODY: ${res.body}");
    if (res.statusCode != 200) {
      throw ApiException(statusCode: res.statusCode, body: res.body);
    }

    final body = jsonDecode(res.body);
    if (body is List) {
      return body
          .map((e) =>
              ParkingCardRequestResponseDTO.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (body is Map<String, dynamic>) {
      return [ParkingCardRequestResponseDTO.fromJson(body)];
    }
    return [];
  }

  // ─────────────────────────────────────────
  // Create Parking Card Request
  // ─────────────────────────────────────────
  static Future<ParkingCardRequestResponseDTO> createParkingCardRequest(
      CreateParkingCardPayload payload) async {
    final attachmentTypes = [
      ...List.filled(payload.vehicleFiles.length, _attachmentTypeVehicle),
      if (payload.selfieFile != null) _attachmentTypeSelfie,
    ];
    final queryString = attachmentTypes.isEmpty
        ? ""
        : "?${attachmentTypes.map((e) => "attachmentTypes=${Uri.encodeQueryComponent(e)}").join("&")}";

    final uri = Uri.parse("$baseUrl/api/v1/parking-card-requests$queryString");

    final request = http.MultipartRequest("POST", uri);
    request.headers["Accept"] = "application/json";

    // ── DTO part ──
    request.files.add(http.MultipartFile.fromString(
      "dto",
      jsonEncode(payload.dto.toJson()),
      filename: "dto.json",
      contentType: MediaType("application", "json"),
    ));

    // ── Vehicle document files ──
    for (int i = 0; i < payload.vehicleFiles.length; i++) {
      request.files.add(await http.MultipartFile.fromPath(
        "files",
        payload.vehicleFiles[i].path,
        filename: payload.vehicleFileNames[i],
      ));
    }

    // ── Selfie file ──
    if (payload.selfieFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        "files",
        payload.selfieFile!.path,
        filename:
            payload.selfieFileName ?? payload.selfieFile!.path.split("/").last,
      ));
    }

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw ApiException(statusCode: resp.statusCode, body: resp.body);
    }

    if (resp.body.isEmpty) return ParkingCardRequestResponseDTO();
    final decoded = jsonDecode(resp.body);
    return ParkingCardRequestResponseDTO.fromJson(
        decoded is Map<String, dynamic> ? decoded : {});
  }
}

// ─────────────────────────────────────────────
// ApiException — structured error
// ─────────────────────────────────────────────

class ApiException implements Exception {
  final int statusCode;
  final String body;

  const ApiException({required this.statusCode, required this.body});

  /// Tries to extract the "message" field from a JSON error body,
  /// falls back to the raw body string.
  String get message {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['message'] as String? ?? body;
      }
    } catch (_) {}
    return body;
  }

  @override
  String toString() => "ApiException($statusCode): $message";
}
