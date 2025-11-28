// lib/core/services/parser/hsbc_parser.dart

import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../models/client_models.dart';
import 'parser_interface.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class HSBCParser extends StatementParser {
  @override
  FinancialInstitution get institution => FinancialInstitution.hsbc;

  // Pattern to find detailed transaction lines, relying on consistent column spacing.
  // The line usually starts with a three-letter code (VIS, DD, TR, BP, etc.) followed by the amount columns.
  // This pattern targets the "Details/Description" line, which contains the amounts.
  static final RegExp _transactionRowPattern = RegExp(
    r'^(?:[A-Z]{2,3}|\>\>\>|\s*)\s*' // Transaction Type (VIS, DD, TR, BP, OBP, >>>, or just empty space)
    r'(.+?)' // Group 1: Details (Non-greedy, captures the full description)
    r'(?:\s{2,})' // Separator: At least two spaces before the Paid Out column
    r'([\d,\.]*)' // Group 2: Paid Out (Expense - may be empty, or contain X,XXX.XX)
    r'(?:\s{2,})' // Separator: At least two spaces before the Paid In column
    r'([\d,\.]*)' // Group 3: Paid In (Income - may be empty, or contain X,XXX.XX)
    r'(?:\s{2,})' // Separator: At least two spaces before the Balance column
    r'([\d,\.]+)?$', // Group 4 (Optional): Balance (not used for transaction, but anchors the line)
  );

  @override
  Future<ValidationResult> validateDocument(
    File pdfFile, {
    String? password,
  }) async {
    try {
      // Try to unlock the PDF first
      final canUnlock = await unlockPdf(pdfFile, password);
      if (!canUnlock) {
        return const ValidationResult(
          canParse: false,
          errorMessage: 'Unable to unlock PDF. Password may be incorrect.',
          missingCheckpoints: ['PDF unlock'],
        );
      }

      // Extract text and check for HSBC markers
      final document = PdfDocument(
        inputBytes: pdfFile.readAsBytesSync(),
        password: password,
      );

      final fullText = PdfTextExtractor(document).extractText();
      document.dispose();

      final missingCheckpoints = <String>[];

      // Check for HSBC-specific markers
      if (!containsInstitutionMarkers(fullText)) {
        missingCheckpoints.add('HSBC institution markers');
      }

      // Check for expected column headers
      if (!fullText.contains('Paid out') && !fullText.contains('£ Paid out')) {
        missingCheckpoints.add('Paid out column header');
      }
      if (!fullText.contains('Paid in') && !fullText.contains('£ Paid in')) {
        missingCheckpoints.add('Paid in column header');
      }
      if (!fullText.contains('Balance') && !fullText.contains('£ Balance')) {
        missingCheckpoints.add('Balance column header');
      }

      // Check for date pattern (e.g., "12 Jun 25")
      if (!RegExp(r'\d{1,2}\s+[A-Z][a-z]{2}\s+\d{2}').hasMatch(fullText)) {
        missingCheckpoints.add('Date format (DD MMM YY)');
      }

      if (missingCheckpoints.isNotEmpty) {
        return ValidationResult(
          canParse: false,
          errorMessage: 'Document does not match HSBC format',
          missingCheckpoints: missingCheckpoints,
        );
      }

      return const ValidationResult(
        canParse: true,
        errorMessage: null,
        missingCheckpoints: [],
      );
    } catch (e) {
      return ValidationResult(
        canParse: false,
        errorMessage: 'Error validating document: $e',
        missingCheckpoints: ['Document validation'],
      );
    }
  }

  @override
  Future<ParseResult> parseDocument(
    File pdfFile,
    UploadedDocument documentMetadata, {
    String? password,
  }) async {
    PdfDocument? document;
    final transactions = <ParsedTransaction>[];

    try {
      document = PdfDocument(
        inputBytes: pdfFile.readAsBytesSync(),
        password: password,
      );

      String fullText = PdfTextExtractor(document).extractText();
      final uuid = const Uuid();
      final lines = fullText.split('\n');

      DateTime? lastSeenDate;

      // Iterate over lines to extract date and transaction details
      for (var line in lines) {
        line = line.trimRight();

        // 1. Try to find a Date Line (e.g., "12 Jun 25")
        final dateMatch = RegExp(r'^\s*(\d{1,2}\s+[A-Z][a-z]{2}\s+\d{2})\s*$')
            .firstMatch(line);
        if (dateMatch != null) {
          lastSeenDate = _parseStatementDate(dateMatch.group(1)!);
          continue;
        }

        // 2. Try to find a Transaction Row
        final match = _transactionRowPattern.firstMatch(line);
        if (match != null && lastSeenDate != null) {
          final rawDetails = match.group(1)!.trim();
          final rawPaidOut = match.group(2)!;
          final rawPaidIn = match.group(3)!;

          double paidOut = parseAmount(rawPaidOut) ?? 0.0;
          double paidIn = parseAmount(rawPaidIn) ?? 0.0;

          double finalAmount = 0.0;

          if (paidIn > 0 && paidOut == 0) {
            finalAmount = paidIn;
          } else if (paidOut > 0 && paidIn == 0) {
            finalAmount = -paidOut; // Expense
          } else {
            continue; // Skip zero or ambiguous transactions
          }

          if (finalAmount == 0.0) continue;

          // Skip balance lines and other non-transaction rows
          if (rawDetails.toUpperCase().contains('BALANCE BROUGHT FORWARD') ||
              rawDetails.toUpperCase().contains('BALANCE CARRIED FORWARD')) {
            continue;
          }

          transactions.add(ParsedTransaction(
            id: uuid.v4(),
            date: lastSeenDate, // Use the last date found
            vendorName: normalizeVendorName(rawDetails),
            amount: finalAmount,
            originalDescription: rawDetails,
            useMemory: false,
          ));
        }
      }

      return ParseResult(
        success: true,
        transactions: transactions,
        document: documentMetadata,
      );
    } catch (e) {
      return ParseResult(
        success: false,
        errorMessage: "Error parsing HSBC PDF: $e",
        document: documentMetadata,
        transactions: [],
      );
    } finally {
      document?.dispose();
    }
  }

  // --- Helper Methods ---

  // HSBC uses a short date format (e.g., 12 Jun 25) which needs custom parsing
  DateTime? _parseStatementDate(String dateString) {
    const monthMap = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12
    };

    try {
      final parts = dateString.trim().split(RegExp(r'\s+'));
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final monthNum = monthMap[parts[1]];
        final shortYear = parts[2];
        final fullYear = int.parse('20$shortYear'); // Assumes 2000s

        if (monthNum != null && day >= 1 && day <= 31) {
          return DateTime(fullYear, monthNum, day);
        }
      }
      return null;
    } catch (e) {
      print('Date parsing error for "$dateString": $e');
      return null;
    }
  }

  @override
  String normalizeVendorName(String rawVendor) {
    // HSBC often has "BRISTOL" or location/account info in the description.
    // Clean up common codes and noise.
    var cleaned = rawVendor
        .replaceAll(RegExp(r'VIS |DD |TR |BP |TFR |CHQ |OBP |>>> '),
            '') // Remove transaction codes first
        .replaceAll('LONDON', '') // Remove common locations
        .replaceAll('BRISTOL', '')
        .replaceAll(RegExp(r'\d{6,}'), '') // Remove long numbers/sort codes
        .replaceAll(RegExp(r'[\u00A0\s]+'),
            ' ') // Replace multiple spaces with one (do this AFTER removals)
        .trim();

    return cleaned;
  }

  @override
  bool containsInstitutionMarkers(String pdfText) {
    final upperText = pdfText.toUpperCase();
    return upperText.contains('HSBC ADVANCE') ||
        upperText.contains('HSBC UK') ||
        (upperText.contains('HSBC') && upperText.contains('YOUR STATEMENT'));
  }

  @override
  DateTime? parseDate(String dateString) {
    return _parseStatementDate(dateString);
  }

  @override
  double? parseAmount(String amountString) {
    if (amountString.isEmpty) return null;
    final cleaned = amountString.replaceAll(RegExp(r'[£,\s]'), '').trim();
    try {
      return double.parse(cleaned);
    } catch (e) {
      return null;
    }
  }

  @override
  List<List<String>> extractTableData(String pdfText) {
    // Simple implementation - can be enhanced if needed
    final lines = pdfText.split('\n');
    final tableData = <List<String>>[];

    for (var line in lines) {
      final match = _transactionRowPattern.firstMatch(line);
      if (match != null) {
        tableData.add([
          match.group(1)?.trim() ?? '', // Description
          match.group(2)?.trim() ?? '', // Paid Out
          match.group(3)?.trim() ?? '', // Paid In
          match.group(4)?.trim() ?? '', // Balance
        ]);
      }
    }

    return tableData;
  }
}
