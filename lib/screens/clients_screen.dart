import 'package:flutter/material.dart';
import '../db/app_database.dart';
import '../models/models.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<Client> _items = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await AppDatabase.instance.clients();
    if (mounted) setState(() => _items = r);
  }

  Future<void> _edit([Client? c]) async {
    final nom = TextEditingController(text: c?.nom ?? '');
    final tel = TextEditingController(text: c?.telephone ?? '');
    final ville = TextEditingController(text: c?.ville ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(c == null ? 'Nouveau client' : 'Modifier le client'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nom, decoration: const InputDecoration(labelText: 'Nom')),
          TextField(
              controller: tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone')),
          TextField(controller: ville, decoration: const InputDecoration(labelText: 'Ville')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok == true && nom.text.trim().isNotEmpty) {
      await AppDatabase.instance.saveClient(Client(
        id: c?.id,
        nom: nom.text.trim(),
        telephone: tel.text.trim(),
        ville: ville.text.trim(),
      ));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        child: const Icon(Icons.person_add),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Rechercher un client...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
        Expanded(child: _items.where((c) =>
          c.nom.toLowerCase().contains(_query) ||
          c.telephone.toLowerCase().contains(_query) ||
          c.ville.toLowerCase().contains(_query)).isEmpty
          ? const Center(child: Text('Aucun client trouvé'))
          : ListView.separated(
              itemCount: _items.where((c) =>
                c.nom.toLowerCase().contains(_query) ||
                c.telephone.toLowerCase().contains(_query) ||
                c.ville.toLowerCase().contains(_query)).length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final filtered = _items.where((c) =>
                  c.nom.toLowerCase().contains(_query) ||
                  c.telephone.toLowerCase().contains(_query) ||
                  c.ville.toLowerCase().contains(_query)).toList();
                final c = filtered[i];
                return Card(child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(c.nom),
                  subtitle: Text([c.telephone, c.ville].where((e) => e.isNotEmpty).join(' • ')),
                  onTap: () => _edit(c),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      try {
                        await AppDatabase.instance.deleteClient(c.id!);
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Impossible : ce client a des factures.')));
                        }
                      }
                      _load();
                    },
                  ),
                ));
              },
            )),
      ]),
    );
  }
}
