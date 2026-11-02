import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../db/app_database.dart';
import '../models/models.dart';
import '../services/pdf_service.dart';
import '../services/thermal_service.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});
  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  List<Client> _clients = [];
  List<PlateType> _types = [];
  final Map<int, int> _qty = {}; // plateTypeId -> quantité
  Client? _client;
  bool _avecTva = true;
  static const double _tauxTva = 20; // TVA Maroc 20 %

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await AppDatabase.instance.clients();
    final t = await AppDatabase.instance.plateTypes();
    if (!mounted) return;
    setState(() {
      _clients = c;
      _types = t;
      if (_client != null && !c.any((e) => e.id == _client!.id)) _client = null;
    });
  }

  List<InvoiceLine> get _lines => _types
      .where((t) => (_qty[t.id] ?? 0) > 0)
      .map((t) => InvoiceLine(
            plateTypeId: t.id,
            designation: t.nom,
            quantite: _qty[t.id]!,
            prixUnitaire: t.prix,
          ))
      .toList();

  double get _ht => _lines.fold(0.0, (s, l) => s + l.total);
  double get _tva => _avecTva ? _ht * _tauxTva / 100 : 0;
  double get _ttc => _ht + _tva;

  Future<Invoice?> _save() async {
    if (_client == null) {
      _msg('Choisissez un client.');
      return null;
    }
    if (_lines.isEmpty) {
      _msg('Ajoutez au moins une plaque.');
      return null;
    }
    final inv = Invoice(
      numero: await AppDatabase.instance.nextInvoiceNumber(),
      date: DateTime.now(),
      client: _client!,
      tauxTva: _avecTva ? _tauxTva : 0,
      lignes: _lines,
    );
    await AppDatabase.instance.saveInvoice(inv);
    setState(_qty.clear);
    return inv;
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pdf() async {
    final inv = await _save();
    if (inv != null) await PdfService.share(inv);
  }

  Future<void> _print() async {
    final inv = await _save();
    if (inv == null) return;

    await [Permission.bluetoothConnect, Permission.bluetoothScan].request();

    if (!await ThermalService.isConnected) {
      final printers = await ThermalService.pairedPrinters();
      if (!mounted) return;
      if (printers.isEmpty) {
        _msg("Aucune imprimante appairée. Appairez-la dans les réglages Bluetooth.");
        return;
      }
      final mac = await showDialog<String>(
        context: context,
        builder: (_) => SimpleDialog(
          title: const Text('Choisir l\'imprimante'),
          children: printers
              .map((p) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, p.macAdress),
                    child: Text('${p.name}\n${p.macAdress}'),
                  ))
              .toList(),
        ),
      );
      if (mac == null) return;
      if (!await ThermalService.connect(mac)) {
        _msg('Connexion impossible à l\'imprimante.');
        return;
      }
    }
    await ThermalService.printInvoice(inv);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle facture')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<Client>(
            value: _client,
            decoration: const InputDecoration(
                labelText: 'Client', border: OutlineInputBorder()),
            items: _clients
                .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text('${c.nom}${c.ville.isEmpty ? '' : ' - ${c.ville}'}')))
                .toList(),
            onChanged: (c) => setState(() => _client = c),
          ),
          if (_clients.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Ajoutez d\'abord un client (onglet Clients).'),
            ),
          const SizedBox(height: 16),
          Text('Plaques', style: Theme.of(context).textTheme.titleMedium),
          ..._types.map((t) {
            final q = _qty[t.id] ?? 0;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.nom),
              subtitle: Text('${t.prix.toStringAsFixed(2)} MAD'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: q > 0 ? () => setState(() => _qty[t.id!] = q - 1) : null,
                ),
                SizedBox(
                    width: 28,
                    child: Text('$q',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16))),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _qty[t.id!] = q + 1),
                ),
              ]),
            );
          }),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Appliquer la TVA (20 %)'),
            value: _avecTva,
            onChanged: (v) => setState(() => _avecTva = v),
          ),
          _totalRow('Total HT', _ht),
          if (_avecTva) _totalRow('TVA 20 %', _tva),
          _totalRow('Total TTC', _ttc, bold: true),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _print,
                icon: const Icon(Icons.print),
                label: const Text('Imprimer'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _pdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDF / WhatsApp'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : null, fontSize: bold ? 18 : 15)),
          Text(mad(v),
              style: TextStyle(fontWeight: bold ? FontWeight.bold : null, fontSize: bold ? 18 : 15)),
        ]),
      );
}
