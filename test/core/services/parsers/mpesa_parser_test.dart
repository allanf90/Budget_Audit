// test/core/services/parsers/hsbc_parser_test.dart

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_audit/core/models/client_models.dart';
import 'package:budget_audit/core/services/parser/hsbc_parser.dart';

void main() {
  late HSBCParser parser;

  setUp(() {
    parser = HSBCParser();
  });




  group('HSBCParser - Logic Helpers', () {
    // Test the custom date parsing (e.g., 12 Jun 25 -> 2025-06-12)
    test('Date parsing handles short year and month name', () {
      print('Testing date parsing...');

      final date1 = parser.parseDate('12 Jun 25');
      print('date1 result: $date1');

      final date2 = parser.parseDate('16 Jan 25');
      print('date2 result: $date2');

      final date3 = parser.parseDate('13 Jun 25');
      print('date3 result: $date3');

      expect(date1, isNotNull, reason: 'Failed to parse "12 Jun 25"');
      expect(date1?.year, 2025);
      expect(date1?.month, 6); // June
      expect(date1?.day, 12);

      expect(date2, isNotNull, reason: 'Failed to parse "16 Jan 25"');
      expect(date2?.year, 2025);
      expect(date2?.month, 1); // January
      expect(date2?.day, 16);

      expect(date3, isNotNull, reason: 'Failed to parse "13 Jun 25"');
      expect(date3?.year, 2025);
      expect(date3?.month, 6); // June
      expect(date3?.day, 13);
    });

    test('Date parsing handles invalid dates', () {
      expect(parser.parseDate('invalid'), isNull);
      expect(parser.parseDate('32 Jun 25'), isNull);
      expect(parser.parseDate(''), isNull);
    });

    // Test that the column-based details are cleaned correctly
    test('normalizeVendorName removes transaction codes and location noise',
        () {
      // Sample 1: "VIS PRIMARK STORES LTD BRISTOL"
      const input1 = "VIS PRIMARK STORES LTD BRISTOL";

      // Sample 2: "OBP From Debit Betting DudleyGrove"
      const input2 = "OBP From Debit Betting DudleyGrove";

      // Sample 3: "DD BMA ASSOCIATION BRISTOL CC L TAX"
      const input3 = "DD BMA ASSOCIATION BRISTOL CC L TAX";

      // Sample 4: Multiple spaces
      const input4 = "VIS   M & S SIMPLY FOOD   BRISTOL";

      expect(parser.normalizeVendorName(input1), equals("PRIMARK STORES LTD"));
      expect(parser.normalizeVendorName(input2),
          equals("From Debit Betting DudleyGrove"));
      expect(parser.normalizeVendorName(input3),
          equals("BMA ASSOCIATION CC L TAX"));
      expect(parser.normalizeVendorName(input4), equals("M & S SIMPLY FOOD"));
    });


    test('parseAmount handles currency symbols and empty strings', () {
      expect(parser.parseAmount("1,100.50"), equals(1100.50));
      expect(parser.parseAmount("£50.00"), equals(50.00));
      expect(parser.parseAmount("2.40"), equals(2.40));
      expect(parser.parseAmount("144.00"), equals(144.00));
      expect(parser.parseAmount(""), isNull);
    });

    test('containsInstitutionMarkers identifies HSBC documents', () {
      const hsbcText1 = "HSBC ADVANCE Your Statement";
      const hsbcText2 = "HSBC UK Bank Account Details";
      const nonHsbcText = "Some other bank statement";

      expect(parser.containsInstitutionMarkers(hsbcText1), isTrue);
      expect(parser.containsInstitutionMarkers(hsbcText2), isTrue);
      expect(parser.containsInstitutionMarkers(nonHsbcText), isFalse);
    });
  });

  group('HSBCParser - Real PDF Tests', () {
    final testPdfPath = 'test/resources/hsbc_statement_sample.pdf';

    test('validateDocument accepts valid HSBC PDF with password', () async {
      final pdfFile = File(testPdfPath);

      if (!pdfFile.existsSync()) {
        print('⚠️  Test PDF not found at $testPdfPath - skipping test');
        return;
      }

      final result = await parser.validateDocument(
        pdfFile,
        password: '0000',
      );

      print('Validation result: ${result.canParse}');
      if (!result.canParse) {
        print('Error: ${result.errorMessage}');
        print('Missing checkpoints: ${result.missingCheckpoints}');
      }

      expect(result.canParse, isTrue,
          reason: result.errorMessage ?? 'Unknown error');
      expect(result.missingCheckpoints, isEmpty);
    });

    test('parseDocument extracts transactions from real PDF', () async {
      final pdfFile = File(testPdfPath);

      if (!pdfFile.existsSync()) {
        print('⚠️  Test PDF not found at $testPdfPath - skipping test');
        return;
      }

      // Create mock document metadata
      final documentMetadata = UploadedDocument(
        id: 'test-doc-1',
        fileName: 'hsbc_statement.pdf',
        filePath: testPdfPath,
        ownerParticipantId: 1,
        uploadedAt: DateTime.now(),
        institution: FinancialInstitution.hsbc,
        //fileSize: pdfFile.lengthSync(),
      );

      final result = await parser.parseDocument(
        pdfFile,
        documentMetadata,
        password: '0000',
      );

      print('Parse result: ${result.success}');
      if (!result.success) {
        print('Error: ${result.errorMessage}');
      }
      print('Transactions found: ${result.transactions.length}');

      expect(result.success, isTrue,
          reason: result.errorMessage ?? 'Parse failed');
      expect(result.transactions, isNotEmpty,
          reason: 'Should extract at least one transaction');

      // Print first few transactions for inspection
      print('\n=== Extracted Transactions ===');
      for (var i = 0; i < result.transactions.length && i < 5; i++) {
        final tx = result.transactions[i];
        print('${i + 1}. ${tx.date.toString().substring(0, 10)} | '
            '${tx.vendorName.padRight(30)} | '
            '£${tx.amount.toStringAsFixed(2).padLeft(10)}');
      }

      // Verify specific transactions from the image
      // Based on the statement image, we expect transactions like:
      // - "M & S SIMPLY FOOD" for £2.40 (12 Jun 25)
      // - "UBER" for £1.20 (12 Jun 25)
      // - "GREGGS PLC" for £2.90 (13 Jun 25)
      // - "PRIMARK STORES LTD" for £52.00 (13 Jun 25)

      final june12Transactions = result.transactions
          .where((tx) => tx.date.day == 12 && tx.date.month == 6)
          .toList();

      expect(
          june12Transactions.any((tx) =>
              tx.vendorName.contains('SIMPLY FOOD') && tx.amount == -2.40),
          isTrue,
          reason: 'Should find M&S SIMPLY FOOD transaction');

      final june13Transactions = result.transactions
          .where((tx) => tx.date.day == 13 && tx.date.month == 6)
          .toList();

      expect(
          june13Transactions.any(
              (tx) => tx.vendorName.contains('PRIMARK') && tx.amount == -52.00),
          isTrue,
          reason: 'Should find PRIMARK transaction');
    });

    test('parseDocument handles income transactions correctly', () async {
      final pdfFile = File(testPdfPath);

      if (!pdfFile.existsSync()) {
        print('⚠️  Test PDF not found at $testPdfPath - skipping test');
        return;
      }

      final documentMetadata = UploadedDocument(
        id: 'test-doc-2',
        fileName: 'hsbc_statement.pdf',
        filePath: testPdfPath,
        ownerParticipantId: 1,
        uploadedAt: DateTime.now(),
        institution: FinancialInstitution.hsbc,
        //fileSize: pdfFile.lengthSync(),
      );

      final result = await parser.parseDocument(
        pdfFile,
        documentMetadata,
        password: '0000',
      );

      expect(result.success, isTrue);

      // Look for income transactions (positive amounts)
      // From the image: "Lincoln Rand" £178.00 (16 Jan 25)
      // "INTERNET TRANSFER" £2,883.00
      final incomeTransactions =
          result.transactions.where((tx) => tx.amount > 0).toList();

      print('\n=== Income Transactions ===');
      for (var tx in incomeTransactions) {
        print('${tx.date.toString().substring(0, 10)} | '
            '${tx.vendorName.padRight(30)} | '
            '£${tx.amount.toStringAsFixed(2).padLeft(10)}');
      }

      expect(incomeTransactions, isNotEmpty,
          reason: 'Should find at least one income transaction');
    });

    test('parseDocument excludes balance rows', () async {
      final pdfFile = File(testPdfPath);

      if (!pdfFile.existsSync()) {
        print('⚠️  Test PDF not found at $testPdfPath - skipping test');
        return;
      }

      final documentMetadata = UploadedDocument(
        id: 'test-doc-3',
        fileName: 'hsbc_statement.pdf',
        ownerParticipantId: 1,
        filePath: testPdfPath,
        uploadedAt: DateTime.now(),
        institution: FinancialInstitution.hsbc,
        //fileSize: pdfFile.lengthSync(),
      );

      final result = await parser.parseDocument(
        pdfFile,
        documentMetadata,
        password: '0000',
      );

      expect(result.success, isTrue);

      // Ensure no "BALANCE BROUGHT FORWARD" or "BALANCE CARRIED FORWARD" in transactions
      final balanceRows = result.transactions
          .where((tx) =>
              tx.vendorName.toUpperCase().contains('BALANCE') ||
              tx.originalDescription!.toUpperCase().contains('BALANCE'))
          .toList();

      expect(balanceRows, isEmpty,
          reason: 'Should not include balance rows as transactions');
    });
  });
}
