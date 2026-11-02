import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/app_database.dart';
import '../models/models.dart';
import '../services/pdf_service.dart';
import '../widgets/shark_logo.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Invoice> _items = [];
  String _filter = '';

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.revision.addListener(_onDatabaseChanged);
    _load();
  }

  @override
  void dispose() {
    AppDatabase.instance.revision.removeListener(_onDatabaseChanged);
    super.dispose();
  }

  void _onDatabaseChanged() => _load();

  Future<void> _load() async {
    final r = await AppDatabase.instance.invoices();
    if (mounted) setState(() => _items = r);
  }

  List<Invoice> get _visibleItems {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((inv) =>
      inv.numero.toLowerCase().contains(q) ||
      inv.client.nom.toLowerCase().contains(q) ||
      DateFormat('dd/MM/yyyy').format(inv.date).contains(q) ||
      inv.lignes.any((l) => l.designation.toLowerCase().contains(q))
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    final items = _visibleItems;
    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          SharkLogo(size: 32), SizedBox(width: 8), Text('Historique'),
        ]),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _filter = v),
            decoration: const InputDecoration(
              hintText: 'Rechercher facture ou client',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(_filter.isEmpty ? 'Aucune facture' : 'Aucun résultat'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final inv = items[i];
                    return ListTile(
                      title: Text('${inv.numero} - ${inv.client.nom}'),
                      subtitle: Text(df.format(inv.date)),
                      trailing: Text(mad(inv.totalTTC),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () => PdfService.share(inv),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
