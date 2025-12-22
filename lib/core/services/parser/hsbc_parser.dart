// lib/core/services/parser/hsbc_parser.dart

import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/client_models.dart';
import 'parser_interface.dart';

/// Parser for HSBC bank statements
///
/// HSBC statements have a unique format where:
/// - Transactions are grouped by date
/// - Each transaction has DR (debit) or CR (credit) prefix
/// - Multiple transactions on the same date are bundled together
/// - Reference codes and payment charges may appear as separate lines
class HSBCParser extends StatementParser {
  final uuid = const Uuid();

  @override
  FinancialInstitution get institution => FinancialInstitution.hsbc;

  @override
  Future<ValidationResult> validateDocument(
    File pdfFile, {
    String? password,
  }) async {
    final missingCheckpoints = <String>[];

    try {
      // Try to unlock the PDF
      if (password != null) {
        final canUnlock = await unlockPdf(pdfFile, password);
        if (!canUnlock) {
          return const ValidationResult(
            canParse: false,
            errorMessage: 'Unable to unlock PDF with provided password',
            missingCheckpoints: ['PDF unlock failed'],
          );
        }
      }

      // Load the PDF document
      final PdfDocument document = PdfDocument(
        inputBytes: pdfFile.readAsBytesSync(),
        password: password,
      );

      // Extract text from all pages
      String fullText = '';
      for (int i = 0; i < document.pages.count; i++) {
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        fullText += extractor.extractText(startPageIndex: i, endPageIndex: i);
      }

      document.dispose();

      // Check for HSBC branding - this is the primary indicator
      if (!fullText.contains('HSBC') && !fullText.contains('hsbc')) {
        missingCheckpoints.add('HSBC branding');
        return ValidationResult(
          canParse: false,
          errorMessage: 'Document does not appear to be an HSBC statement',
          missingCheckpoints: missingCheckpoints,
        );
      }

      // Check for essential column headers that indicate transaction table
      final requiredHeaders = [
        'Date',
        'Paid out',
        'Paid in',
        'Balance',
      ];

      for (final header in requiredHeaders) {
        if (!fullText.contains(header)) {
          missingCheckpoints.add(header);
        }
      }

      // Check for account details section
      if (!fullText.contains('Account Name') &&
          !fullText.contains('Account Nam e')) {
        missingCheckpoints.add('Account details section');
      }

      if (missingCheckpoints.isEmpty) {
        return ValidationResult(
          canParse: true,
          errorMessage: null,
          missingCheckpoints: [],
        );
      } else {
        return ValidationResult(
          canParse: false,
          errorMessage:
              'Missing required elements: ${missingCheckpoints.join(", ")}',
          missingCheckpoints: missingCheckpoints,
        );
      }
    } catch (e) {
      return ValidationResult(
        canParse: false,
        errorMessage: 'Error validating document: $e',
        missingCheckpoints: ['Document validation failed'],
      );
    }
  }

  @override
  Future<ParseResult> parseDocument(
    File pdfFile,
    UploadedDocument documentMetadata, {
    String? password,
  }) async {
    try {
      // Load the PDF document
      final PdfDocument document = PdfDocument(
        inputBytes: pdfFile.readAsBytesSync(),
        password: password,
      );

      // Extract text from all pages
      String fullText = '';
      for (int i = 0; i < document.pages.count; i++) {
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        fullText += extractor.extractText(startPageIndex: i, endPageIndex: i);
      }

      document.dispose();

      // Parse transactions from the extracted text
      final transactions = _extractTransactions(fullText);

      if (transactions.isEmpty) {
        return ParseResult(
          success: false,
          transactions: [],
          errorMessage: 'No transactions found in the document',
          document: documentMetadata,
        );
      }

      return ParseResult(
        success: true,
        transactions: transactions,
        errorMessage: null,
        document: documentMetadata,
      );
    } catch (e) {
      return ParseResult(
        success: false,
        transactions: [],
        errorMessage: 'Error parsing document: $e',
        document: documentMetadata,
      );
    }
  }

  /// Extracts individual transactions from the PDF text
  List<ParsedTransaction> _extractTransactions(String pdfText) {
    final transactions = <ParsedTransaction>[];
    final lines = pdfText.split('\n');

    // Pattern to match transaction lines with date at the start
    // Format: "02 Aug 24 DR/CR VENDOR_NAME"
    final datePattern =
        RegExp(r'^\d{2}\s+[A-Za-z]{3}\s+\d{2}\s+(DR|CR)\s+(.+)');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final match = datePattern.firstMatch(line);

      if (match != null) {
        // Found a transaction line
        final transactionType = match.group(1)!; // DR or CR
        final restOfLine = match.group(2)!;

        // Extract date from the beginning of the line
        final datePart =
            line.substring(0, line.indexOf(transactionType)).trim();
        final transactionDate = parseDate(datePart);

        if (transactionDate == null) continue;

        // Parse the transaction details
        // The line format can be complex, we need to extract:
        // 1. Vendor name (after DR/CR)
        // 2. Amount (last numeric value before balance)
        // 3. Balance (very last number)

        // Look ahead to gather all parts of this transaction
        String fullTransactionText = restOfLine;
        int lookAheadIndex = i + 1;

        // Keep reading lines until we hit another date or find amounts
        while (lookAheadIndex < lines.length) {
          final nextLine = lines[lookAheadIndex].trim();

          // Stop if we hit another transaction date
          if (datePattern.hasMatch(nextLine)) break;

          // Stop if we hit summary lines
          if (nextLine.contains('BALANCE BROUGHT FORWARD') ||
              nextLine.contains('BALANCE CARRIED FORWARD')) break;

          // Add this line to our transaction text
          if (nextLine.isNotEmpty) {
            fullTransactionText += ' ' + nextLine;
          }

          lookAheadIndex++;
        }

        // Now parse the full transaction text
        final parsedTransactions = _parseTransactionBlock(
          transactionDate,
          transactionType,
          fullTransactionText,
        );

        transactions.addAll(parsedTransactions);

        // Skip the lines we've already processed
        i = lookAheadIndex - 1;
      }
    }

    return transactions;
  }

  /// Parses a block of text that represents one or more transactions
  /// on the same date
  List<ParsedTransaction> _parseTransactionBlock(
    DateTime date,
    String transactionType,
    String blockText,
  ) {
    final transactions = <ParsedTransaction>[];

    // Extract all numbers from the text (these are amounts and balances)
    final numberPattern = RegExp(r'[\d,]+\.?\d*');
    final numbers = numberPattern
        .allMatches(blockText)
        .map((m) {
          return parseAmount(m.group(0)!);
        })
        .where((n) => n != null)
        .cast<double>()
        .toList();

    // Split by common separators to find individual transaction parts
    // HSBC often puts reference codes on separate lines
    final parts = blockText.split(RegExp(r'\s{2,}|\n'));

    // Find vendor names (filter out reference codes, payment types, etc.)
    final vendorParts = parts.where((part) {
      final p = part.trim();
      // Skip empty, reference codes, and payment-related keywords
      if (p.isEmpty) return false;
      if (RegExp(r'^[A-Z0-9]{10,}$').hasMatch(p))
        return false; // Reference codes
      if (p == 'PAYMENT CHARGE') return false;
      if (p == 'BIB BACS PAYMENT') return false;
      if (RegExp(r'^\d+\.?\d*$').hasMatch(p)) return false; // Pure numbers
      return true;
    }).toList();

    // Try to intelligently split into individual transactions
    // Look for patterns like "PAYMENT CHARGE" which indicates a separate transaction
    if (blockText.contains('PAYMENT CHARGE') && numbers.length >= 2) {
      // This is at least 2 transactions - main transaction + payment charge

      // First transaction (main)
      final mainVendor = vendorParts.isNotEmpty ? vendorParts[0] : 'Unknown';
      final mainAmount = numbers.isNotEmpty ? numbers[0] : 0.0;

      transactions.add(ParsedTransaction(
        id: uuid.v4(),
        date: date,
        vendorName: normalizeVendorName(mainVendor),
        amount: transactionType == 'DR' ? -mainAmount.abs() : mainAmount.abs(),
        originalDescription: mainVendor,
        useMemory: false,
      ));

      // Second transaction (payment charge)
      final chargeAmount = numbers.length > 1 ? numbers[1] : 0.0;

      transactions.add(ParsedTransaction(
        id: uuid.v4(),
        date: date,
        vendorName: 'Payment Charge',
        amount: -chargeAmount.abs(), // Charges are always negative
        originalDescription: 'PAYMENT CHARGE',
        useMemory: false,
      ));
    } else {
      // Single transaction
      final vendor = vendorParts.isNotEmpty ? vendorParts[0] : 'Unknown';
      final amount = numbers.isNotEmpty ? numbers[0] : 0.0;

      transactions.add(ParsedTransaction(
        id: uuid.v4(),
        date: date,
        vendorName: normalizeVendorName(vendor),
        amount: transactionType == 'DR' ? -amount.abs() : amount.abs(),
        originalDescription: vendor,
        useMemory: false,
      ));
    }

    return transactions;
  }

  @override
  bool containsInstitutionMarkers(String pdfText) {
    return pdfText.contains('HSBC') || pdfText.contains('hsbc');
  }

  @override
  List<List<String>> extractTableData(String pdfText) {
    // HSBC format is complex and doesn't fit a simple table structure
    // This method is kept for interface compliance but not used
    return [];
  }

  @override
  String normalizeVendorName(String rawVendor) {
    // Remove extra whitespace
    String normalized = rawVendor.trim().replaceAll(RegExp(r'\s+'), ' ');

    // Remove common prefixes
    normalized = normalized.replaceAll(RegExp(r'^(BP|CR|DR)\s+'), '');

    // Remove reference codes (long alphanumeric strings)
    normalized = normalized.replaceAll(RegExp(r'\b[A-Z0-9]{10,}\b'), '').trim();

    // Clean up any resulting extra spaces
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    return normalized.isNotEmpty ? normalized : rawVendor;
  }

  @override
  DateTime? parseDate(String dateString) {
    try {
      // HSBC format: "02 Aug 24" or "2 Aug 24"
      dateString = dateString.trim();

      // Try parsing with different formats
      final formats = [
        DateFormat('dd MMM yy'),
        DateFormat('d MMM yy'),
        DateFormat('dd MMM yyyy'),
        DateFormat('d MMM yyyy'),
      ];

      for (final format in formats) {
        try {
          final date = format.parse(dateString);
          // Convert to epoch milliseconds
          return date;
        } catch (e) {
          continue;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
