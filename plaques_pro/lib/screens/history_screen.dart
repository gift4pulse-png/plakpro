import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/app_database.dart';
import '../models/models.dart';
import '../services/pdf_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Invoice> _items = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await AppDatabase.instance.invoices();
    if (mounted) setState(() => _items = r);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Rechercher par numéro ou client...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
        Expanded(child: _items.where((i) =>
          i.numero.toLowerCase().contains(_query) ||
          i.client.nom.toLowerCase().contains(_query)).isEmpty
          ? const Center(child: Text('Aucune facture trouvée'))
          : ListView.separated(
              itemCount: _items.where((i) =>
                i.numero.toLowerCase().contains(_query) ||
                i.client.nom.toLowerCase().contains(_query)).length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final filtered = _items.where((i) =>
                  i.numero.toLowerCase().contains(_query) ||
                  i.client.nom.toLowerCase().contains(_query)).toList();
                final inv = filtered[i];
                return Card(child: ListTile(
                  title: Text('${inv.numero} - ${inv.client.nom}'),
                  subtitle: Text(df.format(inv.date)),
                  trailing: Text(mad(inv.totalTTC),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => PdfService.share(inv),
                ));
              },
            )),
      ]),
    );
  }
}
