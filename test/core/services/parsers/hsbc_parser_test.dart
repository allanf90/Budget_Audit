// test/core/services/parsers/hsbc_parser_test.dart

import 'package:flutter_test/flutter_test.dart';
// Adjust this import to match your actual project name
import 'package:budget_audit/core/models/client_models.dart';
import 'package:budget_audit/core/services/parser/hsbc_parser.dart' as hsbc;
import 'package:budget_audit/core/services/parser/parser_interface.dart'; // For interface types

void main() {
  late hsbc.HSBCParser parser;

  setUp(() {
    parser = hsbc.HSBCParser();
  });

  group('HSBCParser - Logic Helpers', () {
    // Test the custom date parsing (e.g., 12 Jun 25 -> 2025-06-12)
    test('Date parsing handles short year and month name', () {
      // Assuming the statement is from 2025 (as per image)
      final date1 = parser.callParseStatementDate('12 Jun 25');
      final date2 = parser.callParseStatementDate('16 Jan 25');

      expect(date1, isNotNull);
      expect(date1?.year, 2025);
      expect(date1?.month, 6); // June

      expect(date2, isNotNull);
      expect(date2?.month, 1); // January
    });

    // Test that the column-based details are cleaned correctly
    test('normalizeVendorName removes transaction codes and location noise',
        () {
      // Sample 1: "VIS PRIMARK STORES LTD BRISTOL"
      const input1 = "VIS PRIMARK STORES LTD BRISTOL";

      // Sample 2: "OBP From Debit Betting WINNING GROVE"
      const input2 = "OBP From Debit Betting WINNING GROVE";

      // Sample 3: "DD SM AASSOCIATION BRISTOL CC L TAX"
      const input3 = "DD SM AASSOCIATION BRISTOL CC L TAX";

      expect(parser.normalizeVendorName(input1), equals("PRIMARK STORES LTD"));
      expect(parser.normalizeVendorName(input2),
          equals("From Debit Betting WINNING GROVE"));
      expect(parser.normalizeVendorName(input3),
          equals("SM AASSOCIATION CC L TAX")); // Keeps "CC L TAX"
    });

    test('parseAmount handles currency symbols and empty strings', () {
      expect(parser.parseAmount("1,100.50"), equals(1100.50));
      expect(parser.parseAmount("£50.00"), equals(50.00));
      expect(parser.parseAmount(""), isNull);
    });
  });
}

 // 🛑 IMPORTANT: Since _parseStatementDate is private, you need a temporary public wrapper
 // in your HSBCParser class to make it callable from the test:
 extension HSBCParserTestExtension on hsbc.HSBCParser {
   DateTime? callParseStatementDate(String dateString) {
     final currentYear = DateTime.now().year;

    // Attempt to parse: e.g., "12 Jun 25" -> "12 Jun 2025"
    try {
      final parts = dateString.split(' ');
      if (parts.length == 3) {
        final day = parts[0];
        final month = parts[1];
        final shortYear = parts[2]; // e.g., "25"
        final fullYear =
            currentYear.toString().substring(0, 2) + shortYear; // "2025"

        return DateTime.parse('$day $month $fullYear');
      }
      return null;
    } catch (e) {
      return null;
    }
   }
 }
