import 'package:flutter/material.dart';
import '../db/app_database.dart';
import '../models/models.dart';

class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({super.key});
  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  List<PlateType> _items = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await AppDatabase.instance.plateTypes();
    if (mounted) setState(() => _items = r);
  }

  Future<void> _edit([PlateType? t]) async {
    final nom = TextEditingController(text: t?.nom ?? '');
    final prix = TextEditingController(text: t == null ? '' : t.prix.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t == null ? 'Nouveau type' : 'Modifier le type'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nom, decoration: const InputDecoration(labelText: 'Nom')),
          TextField(
            controller: prix,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Prix de vente HT (MAD)'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok == true && nom.text.trim().isNotEmpty) {
      await AppDatabase.instance.savePlateType(PlateType(
        id: t?.id,
        nom: nom.text.trim(),
        prix: double.tryParse(prix.text.replaceAll(',', '.')) ?? 0,
      ));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalogue des plaques')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        child: const Icon(Icons.add),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Rechercher une plaque...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
        Expanded(child: _items.where((t) => t.nom.toLowerCase().contains(_query)).isEmpty
          ? const Center(child: Text('Aucun type de plaque trouvé'))
          : ListView.separated(
              itemCount: _items.where((t) => t.nom.toLowerCase().contains(_query)).length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final filtered = _items.where((t) => t.nom.toLowerCase().contains(_query)).toList();
                final t = filtered[i];
                return Card(child: ListTile(
                  title: Text(t.nom),
                  subtitle: Text('${t.prix.toStringAsFixed(2)} MAD HT'),
                  onTap: () => _edit(t),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Supprimer ce type ?'),
                          content: Text('Voulez-vous supprimer « ${t.nom} » du catalogue ?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await AppDatabase.instance.deletePlateType(t.id!);
                        _load();
                      }
                    },
                  ),
                ));
              },
            )),
      ]),
    );
  }
}
