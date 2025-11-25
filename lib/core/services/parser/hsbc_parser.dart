// lib/core/services/parser/hsbc_parser.dart

import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../models/client_models.dart';
import 'parser_interface.dart';

/// Parser for HSBC bank statements
///
/// Expected Statement Structure:
/// - Header: "HSBC" logo/text
/// - Account format: "XXXX XXXX XXXX XXXX" (16 digits with spaces)
/// - Statement period: "DD MMM YYYY to DD MMM YYYY"
///
/// Transaction Table Columns:
/// 1. Date (DD MMM YYYY, e.g., "15 Jan 2025")
/// 2. Description (vendor/purpose)
/// 3. Amount (with +/- sign, e.g., "-50.00" or "+2000.00")
/// 4. Balance (running balance)
///
/// Example Row:
/// | 15 Jan 2025 | SUPERMARKET PURCHASE | -2,500.00 | 45,000.00 |
class HSBCParser implements StatementParser {
  @override
  FinancialInstitution get institution => FinancialInstitution.hsbc;

  /// Checkpoints to verify in PDF:
  /// 1. "HSBC" text in header
  /// 2. Account number pattern (16 digits with spaces)
  /// 3. Column headers: "Date", "Description", "Amount", "Balance"
  /// 4. Date format: "DD MMM YYYY"
  /// 5. At least one transaction row
  @override
  Future<ValidationResult> validateDocument(
    File pdfFile, {
    String? password,
  }) async {
    // TODO: Implement HSBC validation
    return const ValidationResult.success();
  }

  @override
  Future<ParseResult> parseDocument(
    File pdfFile,
    UploadedDocument documentMetadata, {
    String? password,
  }) async {
    // TODO: Implement HSBC parsing
    return ParseResult(
      success: true,
      transactions: _generateSampleTransactions(documentMetadata),
      document: documentMetadata,
    );
  }

  @override
  Future<bool> unlockPdf(File pdfFile, String? password) async {
    return true;
  }

  @override
  bool containsInstitutionMarkers(String pdfText) {
    return pdfText.toUpperCase().contains('HSBC');
  }

  @override
  List<List<String>> extractTableData(String pdfText) {
    return [];
  }

  @override
  String normalizeVendorName(String rawVendor) {
    // HSBC patterns may include location codes
    // "SUPERMARKET LONDON GB" -> "SUPERMARKET"
    return rawVendor
        .replaceAll(RegExp(r'\s+[A-Z]{2}$'), '') // Remove country codes
        .trim();
  }

  @override
  DateTime? parseDate(String dateString) {
    // HSBC format: DD MMM YYYY (e.g., "15 Jan 2025")
    final months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };

    try {
      final parts = dateString.toLowerCase().split(' ');
      if (parts.length != 3) return null;

      final day = int.parse(parts[0]);
      final month = months[parts[1].substring(0, 3)];
      final year = int.parse(parts[2]);

      if (month == null) return null;

      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  @override
  double? parseAmount(String amountString) {
    final cleaned = amountString.replaceAll(RegExp(r'[£$\s,]'), '').trim();

    try {
      return double.parse(cleaned);
    } catch (e) {
      return null;
    }
  }

  List<ParsedTransaction> _generateSampleTransactions(
    UploadedDocument document,
  ) {
    final uuid = const Uuid();
    return List.generate(
      8,
      (index) => ParsedTransaction(
        id: uuid.v4(),
        date: DateTime.now().subtract(Duration(days: index * 2)),
        vendorName: 'Greggs PLC',
        amount: -2.90,
        useMemory: false,
      ),
    );
  }
}
