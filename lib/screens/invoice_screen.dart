import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../db/app_database.dart';
import '../models/models.dart';
import '../services/pdf_service.dart';
import '../services/thermal_service.dart';
import '../widgets/shark_logo.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});
  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  List<Client> _clients = [];
  List<PlateType> _types = [];
  final Map<int, int> _qty = {}; // plateTypeId -> quantité
  final Map<int, TextEditingController> _qtyControllers = {};
  Client? _client;
  bool _avecTva = true;
  bool _arabic = false;
  String tr(String fr, String ar) => _arabic ? ar : fr;
  static const double _tauxTva = 20; // TVA Maroc 20 %

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.revision.addListener(_onDatabaseChanged);
    _load();
  }

  @override
  void dispose() {
    AppDatabase.instance.revision.removeListener(_onDatabaseChanged);
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onDatabaseChanged() => _load();

  TextEditingController _quantityController(int id) =>
      _qtyControllers.putIfAbsent(
        id,
        () => TextEditingController(text: '${_qty[id] ?? 0}'),
      );

  void _setQuantity(int id, int value) {
    final safeValue = value.clamp(0, 999999999).toInt();
    setState(() => _qty[id] = safeValue);
    final controller = _qtyControllers[id];
    if (controller != null && controller.text != '$safeValue') {
      controller.value = TextEditingValue(
        text: '$safeValue',
        selection: TextSelection.collapsed(offset: '$safeValue'.length),
      );
    }
  }

  Future<void> _load() async {
    final c = await AppDatabase.instance.clients();
    final t = await AppDatabase.instance.plateTypes();
    final language = await AppDatabase.instance.readSetting('language');
    if (!mounted) return;
    setState(() {
      _arabic = language == 'ar';
      _clients = c;
      _types = t;
      if (_client != null) {
        final matches = c.where((e) => e.id == _client!.id);
        _client = matches.isEmpty ? null : matches.first;
      }
      final activeIds = t.map((e) => e.id).whereType<int>().toSet();
      final removedIds = _qtyControllers.keys
          .where((id) => !activeIds.contains(id))
          .toList();
      for (final id in removedIds) {
        _qtyControllers.remove(id)?.dispose();
        _qty.remove(id);
      }
    });
  }


  Future<void> _chooseClient() async {
    final controller = TextEditingController();
    Client? selected;
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialog) {
        final q = controller.text.trim().toLowerCase();
        final matches = _clients.where((c) => q.isEmpty ||
          '${c.nom} ${c.telephone} ${c.ville}'.toLowerCase().contains(q)).toList();
        return AlertDialog(
          title: Text(tr('Rechercher un client', 'البحث عن زبون')),
          content: SizedBox(width: 420, height: 360, child: Column(children: [
            TextField(controller: controller, autofocus: true,
              onChanged: (_) => setDialog(() {}),
              decoration: InputDecoration(prefixIcon: Icon(Icons.search),
                hintText: tr('Nom, téléphone ou ville', 'الاسم أو الهاتف أو المدينة'), border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Expanded(child: matches.isEmpty
              ? Center(child: Text(tr('Aucun client trouvé.', 'ما لقيت حتى زبون.')))
              : ListView.builder(itemCount: matches.length, itemBuilder: (_, i) {
                  final c = matches[i];
                  return ListTile(title: Text(c.nom),
                    subtitle: Text([c.telephone, c.ville].where((v) => v.isNotEmpty).join(' • ')),
                    onTap: () { selected = c; Navigator.pop(dialogContext); });
                })),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('Annuler', 'إلغاء')))],
        );
      },
    ));
    controller.dispose();
    if (selected != null && mounted) setState(() => _client = selected);
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
      _msg(tr('Choisissez un client.', 'اختار الزبون.'));
      return null;
    }
    if (_lines.isEmpty) {
      _msg(tr('Ajoutez au moins un article.', 'زيد سلعة واحدة على الأقل.'));
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
    if (!mounted) return null;
    setState(() {
      _qty.clear();
      for (final controller in _qtyControllers.values) {
        controller.text = '0';
      }
    });
    return inv;
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pdf() async {
    final inv = await _save();
    if (inv != null) await PdfService.share(inv);
  }

  Future<void> _print() async {
    await [Permission.bluetoothConnect, Permission.bluetoothScan].request();

    if (!await ThermalService.isConnected) {
      final printers = await ThermalService.pairedPrinters();
      if (!mounted) return;
      if (printers.isEmpty) {
        _msg(tr('Aucune imprimante appairée. Appairez-la dans les réglages Bluetooth.', 'ما كايناش طابعة مربوطة. ربطها من إعدادات Bluetooth.'));
        return;
      }
      final mac = await showDialog<String>(
        context: context,
        builder: (_) => SimpleDialog(
          title: Text(tr('Choisir l\'imprimante', 'اختيار الطابعة')),
          children: printers
              .map((p) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, p.macAdress),
                    child: Text('${p.name}\n${p.macAdress}'),
                  ))
              .toList(),
        ),
      );
      if (mac == null) return;
      final connected = await ThermalService.connect(mac);
      if (!mounted) return;
      if (!connected) {
        _msg(tr('Connexion impossible à l\'imprimante.', 'تعذر الاتصال بالطابعة.'));
        return;
      }
    }

    // Do not create an invoice if no printer is available.
    final inv = await _save();
    if (inv == null) return;
    await ThermalService.printInvoice(inv);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr, child: Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const SharkLogo(size: 32),
          const SizedBox(width: 8),
          Text(tr('Aluminum Ainaki — Facture', 'Aluminum Ainaki — فاتورة')) ,
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _clients.isEmpty ? null : _chooseClient,
            icon: const Icon(Icons.person_search),
            label: Align(alignment: Alignment.centerLeft,
              child: Text(_client == null
                ? tr('Rechercher et choisir un client', 'البحث واختيار الزبون')
                : '${_client!.nom}${_client!.ville.isEmpty ? '' : ' — ${_client!.ville}'}')),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17)),
          ),
          if (_client != null)
            Align(alignment: Alignment.centerRight, child: TextButton.icon(
              onPressed: () => setState(() => _client = null),
              icon: const Icon(Icons.clear), label: Text(tr('Changer / effacer le client', 'تغيير / مسح الزبون')))),
          if (_clients.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(tr('Ajoutez d\'abord un client (onglet Clients).', 'زيد زبون أولاً من قسم العملاء.')),
            ),
          const SizedBox(height: 16),
          Text(tr('Articles / plaques', 'السلع'), style: Theme.of(context).textTheme.titleMedium),
          ..._types.map((t) {
            final q = _qty[t.id] ?? 0;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.nom),
              subtitle: Text('${t.prix.toStringAsFixed(2)} MAD'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: tr('Diminuer', 'نقص'),
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: q > 0 ? () => _setQuantity(t.id!, q - 1) : null,
                ),
                SizedBox(
                  width: 72,
                  child: TextField(
                    key: ValueKey('quantity-${t.id}'),
                    controller: _quantityController(t.id!),
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      setState(() => _qty[t.id!] = parsed == null || parsed < 0
                          ? 0
                          : parsed.clamp(0, 999999999).toInt());
                    },
                  ),
                ),
                IconButton(
                  tooltip: tr('Augmenter', 'زيد'),
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _setQuantity(t.id!, q + 1),
                ),
              ]),
            );
          }),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Appliquer la TVA (20 %)', 'تطبيق الضريبة 20٪')),
            value: _avecTva,
            onChanged: (v) => setState(() => _avecTva = v),
          ),
          _totalRow(tr('Total HT', 'المجموع بدون ضريبة'), _ht),
          if (_avecTva) _totalRow(tr('TVA 20 %', 'الضريبة 20٪'), _tva),
          _totalRow(tr('Total TTC', 'المجموع شامل الضريبة'), _ttc, bold: true),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _print,
                icon: const Icon(Icons.print),
                label: Text(tr('Imprimer', 'طباعة')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _pdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(tr('PDF / WhatsApp', 'PDF / واتساب')),
              ),
            ),
          ]),
        ],
      ),
    ));
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
