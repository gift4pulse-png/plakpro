import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../models/models.dart';

/// Impression sur imprimante thermique Bluetooth (58 mm ou 80 mm).
/// L'imprimante doit d'abord être appairée dans les réglages Bluetooth d'Android.
class ThermalService {
  static Future<List<BluetoothInfo>> pairedPrinters() =>
      PrintBluetoothThermal.pairedBluetooths;

  static Future<bool> connect(String mac) =>
      PrintBluetoothThermal.connect(macPrinterAddress: mac);

  static Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  static Future<void> printInvoice(
    Invoice inv, {
    String societe = 'Aluminum Ainaki',
    PaperSize paper = PaperSize.mm58,
  }) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(paper, profile);
    final money = NumberFormat('#,##0.00', 'fr_FR');
    final df = DateFormat('dd/MM/yyyy HH:mm');

    // Les caractères accentués dépendent du codepage de l'imprimante :
    // on les retire pour éviter l'affichage de symboles étranges.
    String s(String t) => t
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[àâä]'), 'a')
        .replaceAll(RegExp('[ôö]'), 'o')
        .replaceAll(RegExp('[ùûü]'), 'u')
        .replaceAll(RegExp('[îï]'), 'i')
        .replaceAll('ç', 'c')
        .replaceAll('É', 'E')
        .replaceAll('°', '');

    List<int> b = [];
    b += g.text(s(societe),
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    b += g.text('FACTURE ${inv.numero}', styles: const PosStyles(align: PosAlign.center));
    b += g.text(df.format(inv.date), styles: const PosStyles(align: PosAlign.center));
    b += g.hr();
    b += g.text('Client: ${s(inv.client.nom)}');
    if (inv.client.telephone.isNotEmpty) b += g.text('Tel: ${inv.client.telephone}');
    b += g.hr();

    for (final l in inv.lignes) {
      b += g.text(s(l.designation));
      b += g.row([
        PosColumn(text: '${l.quantite} x ${money.format(l.prixUnitaire)}', width: 7),
        PosColumn(
            text: money.format(l.total),
            width: 5,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    b += g.hr();
    b += g.row([
      PosColumn(text: 'Total HT', width: 6),
      PosColumn(
          text: money.format(inv.totalHT),
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    if (inv.tauxTva > 0) {
      b += g.row([
        PosColumn(text: 'TVA ${inv.tauxTva.toStringAsFixed(0)}%', width: 6),
        PosColumn(
            text: money.format(inv.montantTVA),
            width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    b += g.row([
      PosColumn(text: 'TOTAL TTC', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
          text: '${money.format(inv.totalTTC)} MAD',
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    b += g.feed(1);
    b += g.text('Merci !', styles: const PosStyles(align: PosAlign.center));
    b += g.feed(3);
    b += g.cut();

    await PrintBluetoothThermal.writeBytes(b);
  }
}
