import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/patient_history_models.dart';
import 'base_service.dart';

class PatientHistoryService with AuthenticatedService {
  PatientHistoryService._();
  static final PatientHistoryService instance = PatientHistoryService._();


  Future<ExamHistoryData> fetchHistory(int patientId) async {
    final uri = Uri.parse(
        '${AppConfig.hospitalApiUrl}/patients/$patientId/history');
    debugPrint('[PatientHistoryService] GET $uri');

    try {
      final resp = await http
          .get(uri, headers: await headers)
          .timeout(AppConfig.requestTimeout);

      if (resp.statusCode == 503) {
        throw Exception('Server is temporarily unavailable. Please try again.');
      }
      if (resp.statusCode != 200) {
        throw Exception('Failed to load history (HTTP ${resp.statusCode})');
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        throw Exception(
            (body['message'] as String?) ?? 'Failed to load history');
      }

      return ExamHistoryData.fromJson(body['data'] as Map<String, dynamic>);
    } on TimeoutException {
      throw Exception('Request timed out. Check your connection and try again.');
    } on SocketException {
      throw Exception('Cannot reach server. Check your network connection.');
    }
  }
}
