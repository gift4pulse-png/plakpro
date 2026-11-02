import 'package:flutter_test/flutter_test.dart';
import 'package:plaques_pro/models/models.dart';

void main() {
  group('Invoice totals', () {
    final client = Client(id: 1, nom: 'Test client');

    test('calculates quantities of 100, 300 and 1200 correctly', () {
      final invoice = Invoice(
        numero: 'TEST-1',
        date: DateTime(2026, 11, 2),
        client: client,
        tauxTva: 20,
        lignes: [
          InvoiceLine(
            designation: 'Plaque A',
            quantite: 100,
            prixUnitaire: 10,
          ),
          InvoiceLine(
            designation: 'Plaque B',
            quantite: 300,
            prixUnitaire: 2,
          ),
          InvoiceLine(
            designation: 'Plaque C',
            quantite: 1200,
            prixUnitaire: 1,
          ),
        ],
      );

      expect(invoice.totalHT, 2800);
      expect(invoice.montantTVA, 560);
      expect(invoice.totalTTC, 3360);
    });

    test('zero TVA keeps TTC equal to HT', () {
      final invoice = Invoice(
        numero: 'TEST-2',
        date: DateTime(2026, 11, 2),
        client: client,
        tauxTva: 0,
        lignes: [
          InvoiceLine(
            designation: 'Plaque',
            quantite: 300,
            prixUnitaire: 4.5,
          ),
        ],
      );

      expect(invoice.totalHT, 1350);
      expect(invoice.montantTVA, 0);
      expect(invoice.totalTTC, 1350);
    });
  });
}
