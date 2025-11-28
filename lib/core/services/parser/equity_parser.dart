// lib/core/services/parser/equity_parser.dart

import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../models/client_models.dart';
import 'parser_interface.dart';

/// Parser for Equity Bank statements
///
/// Expected Statement Structure:
/// - Header: "EQUITY BANK LIMITED" or "Equity Bank"
/// - Account format: "XXXX-XXXX-XXXX" (12 digits with hyphens)
/// - Statement period: "From: DD/MM/YYYY To: DD/MM/YYYY"
///
/// Transaction Table Columns:
/// 1. Transaction Date (DD/MM/YYYY)
/// 2. Value Date (DD/MM/YYYY)
/// 3. Description (vendor/purpose)
/// 4. Withdrawal (debit amount)
/// 5. Deposit (credit amount)
/// 6. Balance (running balance)
///
/// Example Row:
/// | 01/01/2025 | 01/01/2025 | POS PURCHASE - SUPERMARKET | 2,500.00 | | 45,000.00 |
class EquityParser implements StatementParser {
  @override
  FinancialInstitution get institution => FinancialInstitution.equity;

  /// Checkpoints to verify in PDF:
  /// 1. "EQUITY BANK" text in header
  /// 2. Account number pattern (XXXX-XXXX-XXXX)
  /// 3. Column headers: "Transaction Date", "Value Date", "Description"
  /// 4. Column headers: "Withdrawal", "Deposit", "Balance"
  /// 5. At least one transaction row with date pattern
  @override
  Future<ValidationResult> validateDocument(
    File pdfFile, {
    String? password,
  }) async {
    // TODO: Implement Equity Bank validation
    //
    // Implementation steps:
    // 1. Load PDF using syncfusion_flutter_pdf
    // 2. Extract text from all pages
    // 3. Check for required checkpoints:
    //    - Bank name in header
    //    - Account number format
    //    - All required column headers
    //    - At least one valid transaction row
    // 4. Return ValidationResult with results

    return const ValidationResult.success();
  }

  @override
  Future<ParseResult> parseDocument(
    File pdfFile,
    UploadedDocument documentMetadata, {
    String? password,
  }) async {
    // TODO: Implement Equity Bank parsing
    //
    // Implementation steps:
    // 1. Load and unlock PDF (if password protected)
    // 2. Extract text from all pages
    // 3. Locate transaction table boundaries
    // 4. Parse each transaction row:
    //    - Extract date (column 1)
    //    - Extract vendor from description (column 3)
    //    - Extract amount from withdrawal OR deposit (columns 4-5)
    //    - Determine if debit (-) or credit (+)
    // 5. Filter out summary rows and headers
    // 6. Convert to ParsedTransaction objects
    // 7. Return ParseResult

    // Stub implementation - returns sample data
    return ParseResult(
      success: true,
      transactions: _generateSampleTransactions(documentMetadata),
      document: documentMetadata,
    );
  }

  @override
  Future<bool> unlockPdf(File pdfFile, String? password) async {
    // TODO: Implement PDF unlocking using syncfusion_flutter_pdf
    return true;
  }

  @override
  bool containsInstitutionMarkers(String pdfText) {
    // TODO: Check for Equity Bank specific markers
    return pdfText.toUpperCase().contains('EQUITY BANK');
  }

  @override
  List<List<String>> extractTableData(String pdfText) {
    // TODO: Extract table rows from PDF text
    // Look for lines matching transaction pattern:
    // DD/MM/YYYY | DD/MM/YYYY | Description | Amount | Amount | Amount
    return [];
  }

  @override
  String normalizeVendorName(String rawVendor) {
    // Common Equity patterns:
    // "POS PURCHASE - SUPERMARKET" -> "SUPERMARKET"
    // "MPESA - JOHN DOE" -> "JOHN DOE"
    // "ATM WITHDRAWAL - 123456" -> "ATM WITHDRAWAL"

    return rawVendor
        .replaceAll(RegExp(r'POS PURCHASE - '), '')
        .replaceAll(RegExp(r'MPESA - '), '')
        .replaceAll(RegExp(r'ATM WITHDRAWAL - \d+'), 'ATM WITHDRAWAL')
        .trim();
  }

  @override
  DateTime? parseDate(String dateString) {
    // Equity format: DD/MM/YYYY
    try {
      final parts = dateString.split('/');
      if (parts.length != 3) return null;

      return DateTime(
        int.parse(parts[2]), // year
        int.parse(parts[1]), // month
        int.parse(parts[0]), // day
      );
    } catch (e) {
      return null;
    }
  }

  @override
  double? parseAmount(String amountString) {
    // Remove currency symbols, commas, and spaces
    final cleaned = amountString.replaceAll(RegExp(r'[KES\s,]'), '').trim();

    try {
      return double.parse(cleaned);
    } catch (e) {
      return null;
    }
  }

  /// Generates sample transactions for stub implementation
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
        reason: null,
        useMemory: false,
      ),
    );
  }
}
