import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

final _money = NumberFormat('#,##0.00', 'fr_FR');
String mad(double v) => '${_money.format(v)} MAD';

class PdfService {
  /// Génère le PDF de la facture (format A5, lisible sur téléphone).
  static Future<Uint8List> build(Invoice inv, {String societe = 'Aluminum Ainaki'}) async {
    final doc = pw.Document();
    final dateFmt = DateFormat('dd/MM/yyyy');

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(societe,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('FACTURE N° ${inv.numero}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text('Date : ${dateFmt.format(inv.date)}'),
          pw.SizedBox(height: 10),
          pw.Text('Client : ${inv.client.nom}'),
          if (inv.client.telephone.isNotEmpty) pw.Text('Tél : ${inv.client.telephone}'),
          if (inv.client.ville.isNotEmpty) pw.Text('Ville : ${inv.client.ville}'),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: ['Désignation', 'Qté', 'P.U.', 'Total'],
            data: inv.lignes
                .map((l) => [
                      l.designation,
                      l.quantite.toString(),
                      _money.format(l.prixUnitaire),
                      _money.format(l.total),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Total HT : ${mad(inv.totalHT)}'),
                if (inv.tauxTva > 0)
                  pw.Text('TVA (${inv.tauxTva.toStringAsFixed(0)}%) : ${mad(inv.montantTVA)}'),
                pw.Text('Total TTC : ${mad(inv.totalTTC)}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.Spacer(),
          pw.Center(child: pw.Text('Merci pour votre confiance')),
        ],
      ),
    ));
    return doc.save();
  }

  /// Ouvre la feuille de partage Android (WhatsApp, e-mail, etc.).
  static Future<void> share(Invoice inv, {String societe = 'Aluminum Ainaki'}) async {
    final bytes = await build(inv, societe: societe);
    await Printing.sharePdf(bytes: bytes, filename: 'Facture_${inv.numero}.pdf');
  }
}
