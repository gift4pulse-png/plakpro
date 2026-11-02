import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/app_database.dart';
import '../models/models.dart';
import '../widgets/shark_logo.dart';

class DistributionScreen extends StatefulWidget {
  const DistributionScreen({super.key});
  @override
  State<DistributionScreen> createState() => _DistributionScreenState();
}

class _DistributionScreenState extends State<DistributionScreen> with SingleTickerProviderStateMixin {
  final db = AppDatabase.instance;
  late final TabController _tabs;
  List<DistributionStock> _stock = [];
  List<Client> _clients = [];
  List<DistributionSaleSummary> _sales = [];
  Map<String, double> _financial = const {'revenue': 0, 'cost': 0, 'expenses': 0};
  List<Map<String, Object?>> _expenses = [];
  bool _loading = true;
  bool _arabic = false;
  String _stockFilter = '';

  String tr(String fr, String ar) => _arabic ? ar : fr;
  String money(double v) => '${NumberFormat('#,##0.00', 'fr_FR').format(v)} MAD';
  String expenseLabel(String key) {
    switch (key) {
      case 'fuel': return tr('Carburant', 'المازوط');
      case 'toll': return tr('Péage / route', 'الطريق والأداء');
      case 'meal': return tr('Repas', 'الماكلة');
      case 'maintenance': return tr('Entretien', 'الصيانة');
      default: return tr('Autre', 'مصروف آخر');
    }
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabChanged);
    db.revision.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    db.revision.removeListener(_refresh);
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _refresh() => _load();

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        db.distributionStock(),
        db.clients(),
        db.distributionSales(),
        db.distributionFinancialSummary(),
        db.distributionExpenses(),
        db.readSetting('language'),
      ]);
      if (!mounted) return;
      setState(() {
        _stock = results[0] as List<DistributionStock>;
        _clients = results[1] as List<Client>;
        _sales = results[2] as List<DistributionSaleSummary>;
        _financial = results[3] as Map<String, double>;
        _expenses = results[4] as List<Map<String, Object?>>;
        _arabic = results[5] == 'ar';
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _message('${tr('Erreur de chargement', 'خطأ في تحميل البيانات')}: $e');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleLanguage() async {
    final next = !_arabic;
    await db.saveSetting('language', next ? 'ar' : 'fr');
    if (mounted) setState(() => _arabic = next);
  }

  List<DistributionStock> get _filteredStock {
    final q = _stockFilter.trim().toLowerCase();
    if (q.isEmpty) return _stock;
    return _stock.where((s) => '${s.product.name} ${s.product.variant}'.toLowerCase().contains(q)).toList();
  }

  Future<void> _editProduct([DistributionProduct? product]) async {
    final name = TextEditingController(text: product?.name ?? '');
    final variant = TextEditingController(text: product?.variant ?? '');
    final pack = TextEditingController(text: product?.piecesPerPack?.toString() ?? '');
    final buy = TextEditingController(text: product?.purchasePrice.toString() ?? '0');
    final sell = TextEditingController(text: product?.salePrice.toString() ?? '0');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(product == null ? tr('Ajouter une référence', 'إضافة نوع سلعة') : tr('Modifier la référence', 'تعديل نوع السلعة')),
      content: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, decoration: InputDecoration(labelText: tr('Nom / type', 'اسم السلعة / النوع')),
          validator: (v) => v == null || v.trim().isEmpty ? tr('Champ obligatoire', 'هذا الحقل ضروري') : null),
        TextFormField(controller: variant, decoration: InputDecoration(labelText: tr('Variante / dimension (ex. 4x4, longue, inversée)', 'الصنف / القياس (مثلاً 4×4، طويلة، معاكسة)'))),
        TextFormField(controller: pack, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: tr('Pièces par paquet (facultatif)', 'عدد القطع في الباكية (اختياري)'), helperText: tr('Laisser vide si variable ou inconnu', 'خليه فارغ إلا كان متغير أو ما معروفش')),
          validator: (v) => v != null && v.trim().isNotEmpty && (int.tryParse(v) == null || int.parse(v) <= 0) ? tr('Nombre invalide', 'عدد غير صحيح') : null),
        TextFormField(controller: buy, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('Prix d’achat par pièce (MAD)', 'ثمن الشراء للقطعة (درهم)'))),
        TextFormField(controller: sell, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('Prix de vente par pièce (MAD)', 'ثمن البيع للقطعة (درهم)'))),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(tr('Annuler', 'إلغاء'))),
        FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(dialogContext, true); }, child: Text(tr('Enregistrer', 'حفظ'))),
      ],
    ));
    if (saved == true) {
      try {
        await db.saveDistributionProduct(DistributionProduct(id: product?.id, name: name.text.trim(),
          variant: variant.text.trim(), piecesPerPack: int.tryParse(pack.text.trim()),
          purchasePrice: double.tryParse(buy.text.replaceAll(',', '.')) ?? 0,
          salePrice: double.tryParse(sell.text.replaceAll(',', '.')) ?? 0));
      } catch (e) { _message(e.toString()); }
    }
    name.dispose(); variant.dispose(); pack.dispose(); buy.dispose(); sell.dispose();
  }

  Future<void> _stockAction(DistributionProduct product, String action) async {
    final packs = TextEditingController(text: '0');
    final pieces = TextEditingController(text: '0');
    final note = TextEditingController();
    final key = GlobalKey<FormState>();
    final title = action == 'in' ? tr('Réception au dépôt', 'إدخال السلعة للمخزن')
      : action == 'load' ? tr('Charger le camion', 'تحميل السلعة فالطونوبيل')
      : tr('Retour du camion au dépôt', 'إرجاع السلعة من الطونوبيل للمخزن');
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Form(key: key, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${product.name}${product.variant.isEmpty ? '' : ' — ${product.variant}'}'),
        if (product.piecesPerPack != null) Text('${tr('1 paquet', 'باكية واحدة')} = ${product.piecesPerPack} ${tr('pièces', 'قطعة')}'),
        TextFormField(controller: packs, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: tr('Nombre de paquets', 'عدد الباكيات')),
          validator: (v) => int.tryParse(v ?? '') == null || int.parse(v!) < 0 ? tr('Nombre invalide', 'عدد غير صحيح') : null),
        TextFormField(controller: pieces, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: tr('Pièces seules / en vrac', 'القطع المفردة')),
          validator: (v) => int.tryParse(v ?? '') == null || int.parse(v!) < 0 ? tr('Nombre invalide', 'عدد غير صحيح') : null),
        TextFormField(controller: note, decoration: InputDecoration(labelText: tr('Note (facultatif)', 'ملاحظة (اختيارية)'))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(tr('Annuler', 'إلغاء'))),
        FilledButton(onPressed: () { if (key.currentState!.validate()) Navigator.pop(dialogContext, true); }, child: Text(tr('Valider', 'تأكيد')))],
    ));
    if (ok == true) {
      try {
        final p = int.parse(packs.text); final n = int.parse(pieces.text);
        if (action == 'in') await db.receiveIntoDepot(product: product, packs: p, loosePieces: n, note: note.text);
        if (action == 'load') await db.loadVehicle(product: product, packs: p, loosePieces: n, note: note.text);
        if (action == 'return') await db.returnVehicleToDepot(product: product, packs: p, loosePieces: n, note: note.text);
        _message(tr('Mouvement enregistré.', 'تم تسجيل حركة المخزون.'));
      } catch (e) { _message(e.toString().replaceFirst('Bad state: ', '')); }
    }
    packs.dispose(); pieces.dispose(); note.dispose();
  }

  Future<Client?> _chooseClient() async {
    final controller = TextEditingController();
    Client? selected;
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialog) {
      final q = controller.text.toLowerCase().trim();
      final matches = _clients.where((c) => q.isEmpty || '${c.nom} ${c.telephone} ${c.ville}'.toLowerCase().contains(q)).toList();
      return AlertDialog(
        title: Text(tr('Choisir un client', 'اختيار الزبون')),
        content: SizedBox(width: 420, height: 360, child: Column(children: [
          TextField(controller: controller, onChanged: (_) => setDialog(() {}),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr('Nom, téléphone ou ville', 'الاسم أو الهاتف أو المدينة'))),
          const SizedBox(height: 8),
          Expanded(child: matches.isEmpty ? Center(child: Text(tr('Aucun client trouvé', 'ما كاين حتى زبون'))) : ListView.builder(
            itemCount: matches.length, itemBuilder: (_, i) { final c = matches[i]; return ListTile(
              title: Text(c.nom), subtitle: Text([c.telephone, c.ville].where((v) => v.isNotEmpty).join(' • ')),
              onTap: () { selected = c; Navigator.pop(dialogContext); }); })),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('Annuler', 'إلغاء')))],
      );
    }));
    controller.dispose();
    return selected;
  }

  Future<DistributionProduct?> _chooseProduct(List<DistributionProduct> products) async {
    final controller = TextEditingController();
    DistributionProduct? selected;
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialog) {
        final q = controller.text.trim().toLowerCase();
        final matches = products.where((p) => q.isEmpty ||
          '${p.name} ${p.variant}'.toLowerCase().contains(q)).toList();
        return AlertDialog(
          title: Text(tr('Rechercher une marchandise', 'البحث عن السلعة')),
          content: SizedBox(width: 420, height: 360, child: Column(children: [
            TextField(controller: controller, autofocus: true, onChanged: (_) => setDialog(() {}),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
                hintText: tr('Nom, référence ou dimension', 'الاسم أو المرجع أو القياس'))),
            const SizedBox(height: 8),
            Expanded(child: matches.isEmpty
              ? Center(child: Text(tr('Aucun produit trouvé.', 'ما لقيت حتى سلعة.')))
              : ListView.builder(itemCount: matches.length, itemBuilder: (_, i) {
                  final p = matches[i];
                  final balance = _stock.where((s) => s.product.id == p.id).first.vehiclePieces;
                  return ListTile(
                    title: Text('${p.name}${p.variant.isEmpty ? '' : ' — ${p.variant}'}'),
                    subtitle: Text('${tr('Disponible dans le camion', 'المتوفر فالطونوبيل')}: $balance ${tr('pièces', 'قطعة')}'),
                    onTap: () { selected = p; Navigator.pop(dialogContext); },
                  );
                })),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('Annuler', 'إلغاء')))],
        );
      },
    ));
    controller.dispose();
    return selected;
  }

  Future<void> _newSale() async {
    if (_stock.where((s) => s.vehiclePieces > 0).isEmpty) {
      _message(tr('Le camion est vide. Chargez d’abord le stock.', 'الطونوبيل خاوية. حمّل السلعة أولاً.'));
      return;
    }
    Client? client;
    final walkIn = TextEditingController();
    final amountPaid = TextEditingController(text: '0');
    final reference = TextEditingController();
    final note = TextEditingController();
    final packs = TextEditingController(text: '0');
    final loose = TextEditingController(text: '0');
    final price = TextEditingController(text: '0');
    DistributionProduct? product;
    final lines = <DistributionSaleLineInput>[];
    String method = 'cash';
    String? error;
    final available = _stock.where((s) => s.vehiclePieces > 0).map((s) => s.product).toList();

    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialog) {
      final total = lines.fold<double>(0, (sum, line) => sum + line.total);
      final selectedStock = product == null ? null : _stock.firstWhere((s) => s.product.id == product!.id, orElse: () => DistributionStock(product: product!, depotPieces: 0, vehiclePieces: 0));
      return AlertDialog(
        title: Text(tr('Nouvelle vente sur tournée', 'بيع جديد عند الزبون')),
        content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          OutlinedButton.icon(onPressed: () async { final c = await _chooseClient(); if (c != null) setDialog(() { client = c; walkIn.text = c.nom; }); },
            icon: const Icon(Icons.person_search), label: Text(client == null ? tr('Rechercher un client', 'البحث عن زبون') : '${client!.nom} — ${client!.ville}')),
          TextField(controller: walkIn, decoration: InputDecoration(labelText: tr('Nom du client / client de passage', 'اسم الزبون')),
            onChanged: (_) { if (client != null && walkIn.text != client!.nom) client = null; }),
          const Divider(height: 22),
          OutlinedButton.icon(
            onPressed: () async {
              final selected = await _chooseProduct(available);
              if (selected != null) setDialog(() {
                product = selected;
                price.text = selected.salePrice.toString();
                packs.text = '0';
                loose.text = '0';
              });
            },
            icon: const Icon(Icons.inventory_2_outlined),
            label: Align(alignment: Alignment.centerLeft, child: Text(product == null
              ? tr('Rechercher et choisir une marchandise', 'البحث واختيار السلعة')
              : '${product!.name}${product!.variant.isEmpty ? '' : ' — ${product!.variant}'}')),
          ),
          if (selectedStock != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text('${tr('Disponible dans le camion', 'المتوفر فالطونوبيل')}: ${selectedStock.vehiclePieces} ${tr('pièces', 'قطعة')}')),
          Row(children: [Expanded(child: TextField(controller: packs, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: tr('Paquets', 'الباكيات')))), const SizedBox(width: 8),
            Expanded(child: TextField(controller: loose, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('Pièces seules', 'قطع مفردة'))))]),
          TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: tr('Prix de vente par pièce (MAD)', 'ثمن البيع للقطعة (درهم)'))),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () {
            try {
              if (product == null) throw StateError(tr('Choisissez un produit.', 'اختار السلعة.'));
              final p = int.tryParse(packs.text) ?? -1; final n = int.tryParse(loose.text) ?? -1;
              final pu = double.tryParse(price.text.replaceAll(',', '.')) ?? -1;
              final line = DistributionSaleLineInput(product: product!, packs: p, loosePieces: n, unitPrice: pu);
              if (line.quantityPieces <= 0 || pu < 0) throw StateError(tr('Vérifiez la quantité et le prix.', 'تأكد من الكمية والثمن.'));
              final alreadyInCart = lines.where((x) => x.product.id == product!.id).fold<int>(0, (sum, x) => sum + x.quantityPieces);
              if (alreadyInCart + line.quantityPieces > selectedStock!.vehiclePieces) throw StateError(tr('Stock camion insuffisant.', 'الكمية فالطونوبيل غير كافية.'));
              setDialog(() { lines.add(line); packs.text = '0'; loose.text = '0'; error = null; });
            } catch (e) { setDialog(() => error = e.toString().replaceFirst('Bad state: ', '')); }
          }, icon: const Icon(Icons.add), label: Text(tr('Ajouter au ticket', 'إضافة للفاتورة')))),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          ...lines.asMap().entries.map((entry) { final i = entry.key; final line = entry.value; return ListTile(
            dense: true, contentPadding: EdgeInsets.zero,
            title: Text('${line.product.name} — ${line.quantityPieces} ${tr('pièces', 'قطعة')}'),
            subtitle: Text('${money(line.unitPrice)} / pièce'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(money(line.total)), IconButton(icon: const Icon(Icons.close), onPressed: () => setDialog(() => lines.removeAt(i))) ])); }),
          const Divider(),
          Text('${tr('Total', 'المجموع')}: ${money(total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          TextField(controller: amountPaid, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: tr('Montant reçu maintenant (MAD)', 'المبلغ اللي توصلتي به دابا (درهم)'))),
          DropdownButtonFormField<String>(initialValue: method, decoration: InputDecoration(labelText: tr('Mode de paiement', 'طريقة الأداء')),
            items: [DropdownMenuItem(value: 'cash', child: Text(tr('Espèces', 'نقداً'))),
              DropdownMenuItem(value: 'transfer_pending', child: Text(tr('Virement envoyé — à confirmer', 'تحويل مرسل — في انتظار التأكيد'))),
              DropdownMenuItem(value: 'credit', child: Text(tr('Crédit / pas encore payé', 'دين / لم يؤد بعد')))],
            onChanged: (v) => setDialog(() => method = v ?? 'cash')),
          if (method == 'transfer_pending') TextField(controller: reference, decoration: InputDecoration(labelText: tr('Référence du virement / message', 'مرجع التحويل أو الرسالة'))),
          TextField(controller: note, decoration: InputDecoration(labelText: tr('Note facultative', 'ملاحظة اختيارية'))),
          if (method == 'credit') Padding(padding: const EdgeInsets.only(top: 5), child: Text(tr('Le montant reçu doit être 0 pour une vente à crédit.', 'في حالة الدين، خلي المبلغ المستلم 0.'), style: const TextStyle(color: Colors.deepOrange))),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(tr('Annuler', 'إلغاء'))),
          FilledButton(onPressed: () {
            final paid = double.tryParse(amountPaid.text.replaceAll(',', '.')) ?? -1;
            final invalidPayment = paid < 0 || paid > total ||
                (method == 'credit' && paid != 0) ||
                (method == 'cash' && paid == 0) ||
                (method == 'transfer_pending' && paid == 0);
            if (lines.isEmpty || (client == null && walkIn.text.trim().isEmpty) || invalidPayment) {
              setDialog(() => error = tr('Vérifiez le client, les articles et le montant. Pour une vente non payée, choisissez Crédit.', 'راجع الزبون والسلعة والمبلغ. إذا ما خلصش الزبون اختار الدين.')); return;
            }
            Navigator.pop(dialogContext, true);
          }, child: Text(tr('Enregistrer la vente', 'حفظ البيع')))],
      );
    }));
    if (saved == true) {
      try {
        await db.createDistributionSale(client: client, walkInName: walkIn.text,
          lines: lines, paidAmount: double.parse(amountPaid.text.replaceAll(',', '.')),
          paymentMethod: method, paymentReference: reference.text, note: note.text);
        _message(tr('Vente enregistrée et stock camion mis à jour.', 'تسجل البيع وتحدّث مخزون الطونوبيل.'));
      } catch (e) { _message(e.toString().replaceFirst('Bad state: ', '')); }
    }
    walkIn.dispose(); amountPaid.dispose(); reference.dispose(); note.dispose(); packs.dispose(); loose.dispose(); price.dispose();
  }

  Future<void> _addExpense() async {
    final amount = TextEditingController();
    final note = TextEditingController();
    String category = 'fuel';
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialog) => AlertDialog(
        title: Text(tr('Nouvelle dépense de tournée', 'مصروف جديد ديال الجولة')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: category,
            decoration: InputDecoration(labelText: tr('Catégorie', 'نوع المصروف')),
            items: [
              DropdownMenuItem(value: 'fuel', child: Text(tr('Carburant', 'المازوط'))),
              DropdownMenuItem(value: 'toll', child: Text(tr('Péage / route', 'الطريق والأداء'))),
              DropdownMenuItem(value: 'meal', child: Text(tr('Repas', 'الماكلة'))),
              DropdownMenuItem(value: 'maintenance', child: Text(tr('Entretien', 'الصيانة'))),
              DropdownMenuItem(value: 'other', child: Text(tr('Autre', 'مصروف آخر'))),
            ], onChanged: (v) => setDialog(() => category = v ?? 'fuel')),
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: tr('Montant (MAD)', 'المبلغ (درهم)'))),
          TextField(controller: note, decoration: InputDecoration(labelText: tr('Note facultative', 'ملاحظة اختيارية'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(tr('Annuler', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(tr('Enregistrer', 'حفظ'))),
        ],
      ),
    ));
    if (ok == true) {
      try {
        await db.saveDistributionExpense(category: category,
          amount: double.parse(amount.text.replaceAll(',', '.')), note: note.text);
      } catch (e) { _message(e.toString()); }
    }
    amount.dispose();
    note.dispose();
  }

  Future<void> _saleDetails(DistributionSaleSummary sale) async {
    var payments = await db.distributionPaymentsForSale(sale.id);
    final saleLines = await db.distributionLinesForSale(sale.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('${sale.clientName} — #${sale.id}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${tr('Total', 'المجموع')}: ${money(sale.total)}'),
                Text('${tr('Confirmé', 'المؤدى')}: ${money(sale.confirmedPaid)}'),
                Text('${tr('Transfert en attente', 'تحويل في الانتظار')}: ${money(sale.pendingTransfer)}'),
                Text('${tr('Reste dû', 'الدين المتبقي')}: ${money(sale.remaining)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                Text(tr('Articles livrés', 'السلع المسلمة'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ...saleLines.map((line) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(
                  '${line['product_name_snapshot']} ${line['variant_snapshot'] ?? ''} — ${line['quantity_pieces']} ${tr('pièces', 'قطعة')} — ${money((line['line_total'] as num).toDouble())}'))),
                const Divider(),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: payments.map((payment) {
                      final isPending = payment['status'] == 'pending';
                      return ListTile(
                        dense: true,
                        title: Text('${money((payment['amount'] as num).toDouble())} — ${payment['method']}'),
                        subtitle: Text('${payment['status']} ${payment['reference'] ?? ''}'),
                        trailing: isPending
                            ? IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                                tooltip: tr('Confirmer le virement', 'تأكيد التحويل'),
                                onPressed: () async {
                                  await db.confirmDistributionTransfer(payment['id'] as int);
                                  payments = await db.distributionPaymentsForSale(sale.id);
                                  setDialog(() {});
                                },
                              )
                            : const Icon(Icons.check, color: Colors.green),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('Fermer', 'إغلاق'))),
            if ((sale.total - sale.confirmedPaid - sale.pendingTransfer) > 0.009)
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _addPayment(sale);
                },
                icon: const Icon(Icons.payments),
                label: Text(tr('Ajouter paiement', 'إضافة أداء')),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPayment(DistributionSaleSummary sale) async {
    final unreserved = (sale.total - sale.confirmedPaid - sale.pendingTransfer).clamp(0, double.infinity).toDouble();
    final amount = TextEditingController(text: unreserved.toStringAsFixed(2));
    final reference = TextEditingController();
    String method = 'cash';
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
      title: Text(tr('Ajouter un paiement', 'إضافة أداء')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${tr('Montant encore disponible à encaisser', 'المبلغ المتبقي للتحصيل')}: ${money(unreserved)}'),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('Montant', 'المبلغ'))),
        DropdownButtonFormField<String>(initialValue: method, decoration: InputDecoration(labelText: tr('Mode', 'الطريقة')),
          items: [DropdownMenuItem(value: 'cash', child: Text(tr('Espèces', 'نقداً'))), DropdownMenuItem(value: 'transfer_pending', child: Text(tr('Virement à confirmer', 'تحويل في انتظار التأكيد')))],
          onChanged: (v) => setDialog(() => method = v ?? 'cash')),
        if (method == 'transfer_pending') TextField(controller: reference, decoration: InputDecoration(labelText: tr('Référence', 'المرجع'))),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Annuler', 'إلغاء'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Enregistrer', 'حفظ')))],
    )));
    if (ok == true) {
      try { await db.addDistributionPayment(saleId: sale.id, amount: double.parse(amount.text.replaceAll(',', '.')), method: method, reference: reference.text); }
      catch (e) { _message(e.toString().replaceFirst('Bad state: ', '')); }
    }
    amount.dispose(); reference.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = _arabic ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(textDirection: direction, child: Scaffold(
      appBar: AppBar(title: Row(mainAxisSize: MainAxisSize.min, children: [const SharkLogo(size: 30), const SizedBox(width: 8), Text(tr('Distribution', 'التوزيع'))]),
        actions: [TextButton(onPressed: _toggleLanguage, child: Text(_arabic ? 'FR' : 'عربي', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))],
        bottom: TabBar(controller: _tabs, onTap: (_) => setState(() {}), tabs: [Tab(text: tr('Stock', 'المخزون')), Tab(text: 'Ventes / المبيعات'), Tab(text: tr('Résumé', 'ملخص'))])),
      body: _loading ? const Center(child: CircularProgressIndicator()) : TabBarView(controller: _tabs, children: [_stockTab(), _salesTab(), _summaryTab()]),
      floatingActionButton: _tabs.index == 0 ? FloatingActionButton.extended(onPressed: () => _editProduct(), icon: const Icon(Icons.add), label: Text(tr('Nouveau produit', 'سلعة جديدة'))) :
        _tabs.index == 1 ? FloatingActionButton.extended(onPressed: _newSale, icon: const Icon(Icons.point_of_sale), label: Text(tr('Nouvelle vente', 'بيع جديد'))) :
        _tabs.index == 2 ? FloatingActionButton.extended(onPressed: _addExpense, icon: const Icon(Icons.add), label: Text(tr('Ajouter dépense', 'إضافة مصروف'))) : null,
    ));
  }

  Widget _stockTab() {
    final list = _filteredStock;
    final depotTotal = _stock.fold<int>(0, (s, x) => s + x.depotPieces);
    final vanTotal = _stock.fold<int>(0, (s, x) => s + x.vehiclePieces);
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: _metric(tr('Au dépôt', 'فالمخزن'), '$depotTotal ${tr('pièces', 'قطعة')}', Icons.warehouse_outlined)),
        const SizedBox(width: 8), Expanded(child: _metric(tr('Dans le camion', 'فالطونوبيل'), '$vanTotal ${tr('pièces', 'قطعة')}', Icons.local_shipping_outlined)),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: TextField(onChanged: (v) => setState(() => _stockFilter = v),
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr('Chercher type, dimension…', 'قلب على النوع أو القياس…'), border: const OutlineInputBorder()))),
      Expanded(child: list.isEmpty ? Center(child: Text(tr('Aucun produit. Ajoutez vos références.', 'ما كايناش سلع. زيد الأنواع ديالك.'))) : ListView.separated(
        itemCount: list.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
          final s = list[i]; final p = s.product;
          return ListTile(title: Text('${p.name}${p.variant.isEmpty ? '' : ' — ${p.variant}'}'),
            subtitle: Text('${tr('Dépôt', 'المخزن')}: ${s.depotPieces}  •  ${tr('Camion', 'الطونوبيل')}: ${s.vehiclePieces}${p.piecesPerPack == null ? '' : '  •  ${p.piecesPerPack}/${tr('paquet', 'باكية')}'}'),
            trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _editProduct(p); else _stockAction(p, v); }, itemBuilder: (_) => [
              PopupMenuItem(value: 'in', child: Text(tr('Réception dépôt', 'إدخال للمخزن'))),
              PopupMenuItem(value: 'load', child: Text(tr('Charger camion', 'تحميل الطونوبيل'))),
              PopupMenuItem(value: 'return', child: Text(tr('Retour au dépôt', 'إرجاع للمخزن'))),
              PopupMenuItem(value: 'edit', child: Text(tr('Modifier produit', 'تعديل السلعة'))),
            ], child: const Icon(Icons.more_vert)));
        })),
    ]);
  }

  Widget _salesTab() => _sales.isEmpty ? Center(child: Text(tr('Aucune vente de distribution enregistrée.', 'مازال ما تسجل حتى بيع.'))) : ListView.separated(
    padding: const EdgeInsets.only(bottom: 90), itemCount: _sales.length, separatorBuilder: (_, __) => const Divider(height: 1),
    itemBuilder: (_, i) { final s = _sales[i]; return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.storefront)), title: Text(s.clientName),
      subtitle: Text('${DateFormat('dd/MM/yyyy HH:mm').format(s.date)}${s.city.isEmpty ? '' : ' • ${s.city}'}\n${tr('Payé', 'المؤدى')}: ${money(s.confirmedPaid)}  |  ${tr('Reste', 'الباقي')}: ${money(s.remaining)}'),
      isThreeLine: true, trailing: Text(money(s.total), style: const TextStyle(fontWeight: FontWeight.bold)), onTap: () => _saleDetails(s)); });

  Widget _summaryTab() {
    final total = _sales.fold<double>(0, (s, x) => s + x.total);
    final paid = _sales.fold<double>(0, (s, x) => s + x.confirmedPaid);
    final pending = _sales.fold<double>(0, (s, x) => s + x.pendingTransfer);
    final due = _sales.fold<double>(0, (s, x) => s + x.remaining);
    final cost = _financial['cost'] ?? 0;
    final expenses = _financial['expenses'] ?? 0;
    final estimatedProfit = (_financial['revenue'] ?? 0) - cost - expenses;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _metric(tr('Ventes enregistrées', 'المبيعات المسجلة'), money(total), Icons.trending_up),
      const SizedBox(height: 10),
      _metric(tr('Argent encaissé', 'المبالغ المقبوضة'), money(paid), Icons.payments),
      const SizedBox(height: 10),
      _metric(tr('Virements à confirmer', 'تحويلات في انتظار التأكيد'), money(pending), Icons.hourglass_top),
      const SizedBox(height: 10),
      _metric(tr('Crédit restant', 'الدين المتبقي'), money(due), Icons.account_balance_wallet),
      const Divider(height: 28),
      Text(tr('Rentabilité estimée', 'الربحية التقديرية'), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      _metric(tr('Coût d’achat des articles vendus', 'تكلفة شراء السلع المباعة'), money(cost), Icons.inventory_2_outlined),
      const SizedBox(height: 8),
      _metric(tr('Dépenses de tournée', 'مصاريف الجولة'), money(expenses), Icons.local_gas_station),
      const SizedBox(height: 8),
      _metric(tr('Résultat estimé', 'النتيجة التقديرية'), money(estimatedProfit), Icons.account_balance),
      const SizedBox(height: 16),
      Text(tr('Dernières dépenses', 'آخر المصاريف'), style: Theme.of(context).textTheme.titleMedium),
      if (_expenses.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(tr('Aucune dépense enregistrée.', 'ما تسجل حتى مصروف.'))),
      ..._expenses.take(8).map((e) => ListTile(dense: true,
        title: Text('${expenseLabel(e['category'] as String)} — ${money((e['amount'] as num).toDouble())}'),
        subtitle: Text('${DateFormat('dd/MM/yyyy').format(DateTime.parse(e['created_at'] as String))} ${e['note'] ?? ''}'))),
      const SizedBox(height: 12),
      Text(tr('Le résultat est une estimation basée sur les coûts d’achat renseignés dans chaque produit et les dépenses saisies.', 'النتيجة تقديرية وكتعتمد على أثمنة الشراء المسجلة ومصاريف الجولة اللي دخلتي.'), style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  Widget _metric(String label, String value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
    CircleAvatar(backgroundColor: const Color(0xFFFFE1DE), foregroundColor: const Color(0xFFC62828), child: Icon(icon)),
    const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 3), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]))
  ])));
}
