// lib/core/services/parser/parser_interface.dart

import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../models/client_models.dart';

/// Abstract base class for all bank statement parsers
///
/// Each parser implementation must:
/// 1. Validate the PDF structure to ensure it can be parsed
/// 2. Extract transactions from the PDF document
/// 3. Handle institution-specific formats and quirks
abstract class StatementParser {
  /// The financial institution this parser handles
  FinancialInstitution get institution;

  /// Validates whether this parser can successfully parse the given PDF
  ///
  /// This method should check for:
  /// - Required column headers (e.g., "Date", "Description", "Amount")
  /// - Expected table structure
  /// - Institution-specific markers (logos, account number formats)
  /// - Page layout compatibility
  ///
  /// Returns [ValidationResult] indicating:
  /// - canParse: true if all checkpoints are found
  /// - errorMessage: description of what's missing or incompatible
  /// - missingCheckpoints: list of specific elements that couldn't be found
  ///
  /// Example checkpoints for Equity Bank:
  /// - "Transaction Date" column header
  /// - "Value Date" column header
  /// - "Description" column header
  /// - "Withdrawal" column header
  /// - "Deposit" column header
  /// - "Balance" column header
  /// - Account number format: "XXXX-XXXX-XXXX"
  Future<ValidationResult> validateDocument(
    File pdfFile, {
    String? password,
  });

  /// Extracts transactions from the PDF document
  ///
  /// Prerequisites:
  /// - validateDocument() must return success before calling this
  /// - PDF must be unlocked (password provided if required)
  ///
  /// Returns [ParseResult] containing:
  /// - success: whether parsing completed without errors
  /// - transactions: list of extracted ParsedTransaction objects
  /// - errorMessage: details if parsing failed partway through
  ///
  /// Implementation requirements:
  /// 1. Read PDF content (text extraction)
  /// 2. Locate transaction table boundaries
  /// 3. Parse each row into fields (date, vendor, amount, etc.)
  /// 4. Handle multi-page statements
  /// 5. Clean and normalize data:
  ///    - Parse dates to DateTime
  ///    - Extract numeric amounts (handle currency symbols)
  ///    - Normalize vendor names (trim, remove extra spaces)
  /// 6. Filter out:
  ///    - Summary rows (totals, balances)
  ///    - Header/footer repetitions
  ///    - Non-transaction content
  ///
  /// Note: Do NOT access the database in this method.
  /// Return in-memory ParsedTransaction objects only.
  Future<ParseResult> parseDocument(
    File pdfFile,
    UploadedDocument documentMetadata, {
    String? password,
  });

  /// Helper method to unlock a password-protected PDF
  ///
  /// Returns true if:
  /// - PDF is not password-protected, OR
  /// - Correct password was provided and PDF was unlocked
  ///
  /// Returns false if password is incorrect or PDF cannot be opened
  Future<bool> unlockPdf(File pdfFile, String? password) async {
    try {
      final doc = PdfDocument(
          inputBytes: pdfFile.readAsBytesSync(), password: password);
      doc.dispose();
      return true;
    } catch (e) {
      // If the document fails to load or the password is wrong
      return false;
    }
  }

  /// Validates that extracted text contains expected patterns
  ///
  /// This is a helper for validateDocument() implementations.
  /// Check for institution-specific patterns like:
  /// - Bank name/logo text
  /// - "Statement of Account" heading
  /// - Account number format
  /// - Statement period format
  bool containsInstitutionMarkers(String pdfText);

  /// Extracts table data from PDF text
  ///
  /// This is a helper for parseDocument() implementations.
  /// Should return a list of rows, where each row is a list of cell values.
  ///
  /// Example for a simple table:
  /// [
  ///   ["Date", "Description", "Amount"],
  ///   ["01/01/2025", "Groceries", "-50.00"],
  ///   ["02/01/2025", "Salary", "+2000.00"],
  /// ]
  List<List<String>> extractTableData(String pdfText);

  /// Cleans and normalizes a vendor name
  ///
  /// Common transformations:
  /// - Trim whitespace
  /// - Remove duplicate spaces
  /// - Remove transaction codes (e.g., "POS 12345 - SuperMart" -> "SuperMart")
  /// - Normalize case (optional)
  String normalizeVendorName(String rawVendor);

  /// Parses a date string in the institution's format
  ///
  /// Each bank may use different date formats:
  /// - Equity: "DD/MM/YYYY"
  /// - HSBC: "DD MMM YYYY"
  /// - M-PESA: "DD/MM/YY HH:MM"
  ///
  /// Returns null if date cannot be parsed
  DateTime? parseDate(String dateString);

  /// Parses an amount string to a double
  ///
  /// Handles:
  /// - Currency symbols (KES, $, £, etc.)
  /// - Thousand separators (commas)
  /// - Negative amounts (parentheses or minus sign)
  /// - Debit/credit indicators
  ///
  /// Returns null if amount cannot be parsed
  double? parseAmount(String amountString){
    final cleaned = amountString.replaceAll(RegExp(r'[£KES\$\s,]'), '').trim();
    try {
      return double.parse(cleaned);
    } catch (e) {
      return null;
    }
  }
}
