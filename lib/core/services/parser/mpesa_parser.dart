// lib/core/services/parser/mpesa_parser.dart

import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../models/client_models.dart';
import 'parser_interface.dart';

/// Parser for M-PESA statements
///
/// Expected Statement Structure:
/// - Header: "M-PESA Statement" or "Safaricom M-PESA"
/// - Phone number format: "+254XXXXXXXXX"
/// - Statement period: "Statement from DD/MM/YY to DD/MM/YY"
///
/// Transaction Table Columns:
/// 1. Completion Time (DD/MM/YY HH:MM)
/// 2. Details (transaction type and party)
/// 3. Transaction Status (Completed/Failed)
/// 4. Paid In (credit amount)
/// 5. Withdrawn (debit amount)
/// 6. Balance (running balance)
///
/// Example Row:
/// | 15/01/25 14:30 | Sent to JOHN DOE - 0712345678 | Completed | | 500.00 | 4,500.00 |
class MPesaParser implements StatementParser {
  @override
  FinancialInstitution get institution => FinancialInstitution.mpesa;

  /// Checkpoints to verify in PDF:
  /// 1. "M-PESA" or "MPESA" text in header
  /// 2. Phone number format (+254XXXXXXXXX)
  /// 3. Column headers: "Completion Time", "Details", "Transaction Status"
  /// 4. Column headers: "Paid In", "Withdrawn", "Balance"
  /// 5. Date format: DD/MM/YY HH:MM
  /// 6. At least one completed transaction
  @override
  Future<ValidationResult> validateDocument(
    File pdfFile, {
    String? password,
  }) async {
    // TODO: Implement M-PESA validation
    return const ValidationResult.success();
  }

  @override
  Future<ParseResult> parseDocument(
    File pdfFile,
    UploadedDocument documentMetadata, {
    String? password,
  }) async {
    // TODO: Implement M-PESA parsing
    //
    // Special considerations:
    // 1. Only include "Completed" transactions
    // 2. Parse transaction type from Details:
    //    - "Sent to [NAME]" -> Send Money
    //    - "Received from [NAME]" -> Received
    //    - "Paid to [MERCHANT]" -> Till/Paybill
    //    - "Withdraw from [AGENT]" -> Withdrawal
    //    - "Deposit to [AGENT]" -> Deposit
    // 3. Extract recipient/sender name as vendor
    // 4. Handle both Paid In and Withdrawn columns

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
    return pdfText.toUpperCase().contains('M-PESA') ||
        pdfText.toUpperCase().contains('MPESA');
  }

  @override
  List<List<String>> extractTableData(String pdfText) {
    return [];
  }

  @override
  String normalizeVendorName(String rawVendor) {
    // M-PESA patterns:
    // "Sent to JOHN DOE - 0712345678" -> "JOHN DOE"
    // "Paid to SUPERMARKET - Till 123456" -> "SUPERMARKET"
    // "Withdraw from Agent - 0712345678" -> "Agent"

    return rawVendor
        .replaceAll(
            RegExp(
                r'Sent to |Received from |Paid to |Withdraw from |Deposit to '),
            '')
        .replaceAll(RegExp(r' - \d+'), '') // Remove phone/till numbers
        .trim();
  }

  @override
  DateTime? parseDate(String dateString) {
    // M-PESA format: DD/MM/YY HH:MM
    try {
      final parts = dateString.split(' ');
      if (parts.length != 2) return null;

      final dateParts = parts[0].split('/');
      final timeParts = parts[1].split(':');

      if (dateParts.length != 3 || timeParts.length != 2) return null;

      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      int year = int.parse(dateParts[2]);

      // Convert 2-digit year to 4-digit (assume 2000s)
      if (year < 100) {
        year += 2000;
      }

      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  @override
  double? parseAmount(String amountString) {
    final cleaned = amountString.replaceAll(RegExp(r'[KSh\s,]'), '').trim();

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
