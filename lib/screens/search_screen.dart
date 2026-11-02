import 'package:flutter/material.dart';
import '../db/app_database.dart';
import '../models/models.dart';
import '../widgets/shark_logo.dart';
import '../services/pdf_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<GlobalSearchResult> _results = [];
  String _query = '';
  bool _loading = false;
  int _requestId = 0;
  bool _arabic = false;
  String tr(String fr, String ar) => _arabic ? ar : fr;

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.revision.addListener(_onDatabaseChanged);
    _loadLanguage();
  }

  @override
  void dispose() {
    AppDatabase.instance.revision.removeListener(_onDatabaseChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onDatabaseChanged() {
    if (_query.trim().isNotEmpty) _search(_query);
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final language = await AppDatabase.instance.readSetting('language');
    if (mounted && _arabic != (language == 'ar')) setState(() => _arabic = language == 'ar');
  }

  String _categoryLabel(String category) {
    if (!_arabic) return category;
    switch (category) {
      case 'Client': return 'زبون';
      case 'Plaque': return 'نوع قديم';
      case 'Stock': return 'مخزون';
      case 'Vente': return 'بيع';
      case 'Facture': return 'فاتورة';
      default: return category;
    }
  }

  Future<void> _search(String value) async {
    _query = value;
    final request = ++_requestId;
    if (value.trim().isEmpty) {
      if (mounted) setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await AppDatabase.instance.searchAll(value);
      if (!mounted || request != _requestId) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _requestId) return;
      setState(() => _loading = false);
    }
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'Client': return Icons.person_outline;
      case 'Plaque': return Icons.directions_car_outlined;
      case 'Stock': return Icons.inventory_2_outlined;
      case 'Vente': return Icons.storefront_outlined;
      default: return Icons.receipt_long;
    }
  }

  Future<void> _openResult(GlobalSearchResult item) async {
    if (item.id == null) return;
    switch (item.category) {
      case 'Client': {
        final clients = await AppDatabase.instance.clients();
        final matches = clients.where((c) => c.id == item.id);
        if (matches.isEmpty || !mounted) return;
        final client = matches.first;
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
          title: Text(client.nom),
          content: Text([client.telephone, client.ville].where((v) => v.isNotEmpty).join('\n')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Fermer', 'إغلاق')))],
        ));
        break;
      }
      case 'Plaque': {
        final types = await AppDatabase.instance.plateTypes();
        final matches = types.where((p) => p.id == item.id);
        if (matches.isEmpty || !mounted) return;
        final plate = matches.first;
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
          title: Text(plate.nom),
          content: Text('${plate.prix.toStringAsFixed(2)} MAD HT'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Fermer', 'إغلاق')))],
        ));
        break;
      }
      case 'Stock': {
        final stock = await AppDatabase.instance.distributionStock();
        final matches = stock.where((s) => s.product.id == item.id);
        if (matches.isEmpty || !mounted) return;
        final entry = matches.first;
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
          title: Text('${entry.product.name} ${entry.product.variant}'),
          content: Text('${tr('Dépôt', 'المخزن')} : ${entry.depotPieces} ${tr('pièces', 'قطعة')}\n${tr('Camion', 'الطونوبيل')} : ${entry.vehiclePieces} ${tr('pièces', 'قطعة')}\n${tr('Prix', 'الثمن')} : ${entry.product.salePrice.toStringAsFixed(2)} MAD / ${tr('pièce', 'قطعة')}'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Fermer', 'إغلاق')))],
        ));
        break;
      }
      case 'Facture': {
        final invoices = await AppDatabase.instance.invoices();
        final matches = invoices.where((inv) => inv.id == item.id);
        if (matches.isNotEmpty) await PdfService.share(matches.first);
        break;
      }
      case 'Vente': {
        final sales = await AppDatabase.instance.distributionSales();
        final matches = sales.where((sale) => sale.id == item.id);
        if (matches.isEmpty || !mounted) return;
        final sale = matches.first;
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
          title: Text('${sale.clientName} — #${sale.id}'),
          content: Text('${tr('Total', 'المجموع')} : ${sale.total.toStringAsFixed(2)} MAD\n${tr('Payé', 'المؤدى')} : ${sale.confirmedPaid.toStringAsFixed(2)} MAD\n${tr('Virement en attente', 'تحويل في الانتظار')} : ${sale.pendingTransfer.toStringAsFixed(2)} MAD\n${tr('Reste', 'الباقي')} : ${sale.remaining.toStringAsFixed(2)} MAD'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Fermer', 'إغلاق')))],
        ));
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr, child: Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const SharkLogo(size: 32), const SizedBox(width: 8), Text(tr('Recherche générale', 'البحث الشامل')),
        ]),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: _controller,
            onChanged: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: tr('Nom, téléphone, plaque ou facture…', 'الاسم أو الهاتف أو السلعة أو الفاتورة…'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: tr('Effacer', 'مسح'),
                      onPressed: () {
                        _controller.clear();
                        _search('');
                      },
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _query.trim().isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      tr('Recherchez ici les clients, les types de plaques et les anciennes factures.', 'قلب هنا على الزبناء والسلع والفواتير القديمة.' ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _results.isEmpty && !_loading
                  ? Center(child: Text(tr('Aucun résultat trouvé.', 'ما لقيت حتى نتيجة.')))
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = _results[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFFFE1DE),
                            foregroundColor: const Color(0xFFC62828),
                            child: Icon(_iconFor(item.category)),
                          ),
                          title: Text(item.title),
                          subtitle: Text(item.subtitle),
                          onTap: () => _openResult(item),
                          trailing: Chip(
                            label: Text(_categoryLabel(item.category)),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide.none,
                            backgroundColor: const Color(0xFFFFE1DE),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    ));
  }
}
