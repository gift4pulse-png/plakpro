import 'package:flutter/material.dart';
import '../db/app_database.dart';
import '../models/models.dart';
import '../widgets/shark_logo.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<Client> _items = [];
  String _filter = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.revision.addListener(_onDatabaseChanged);
    _load();
  }

  @override
  void dispose() {
    AppDatabase.instance.revision.removeListener(_onDatabaseChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onDatabaseChanged() => _load();

  Future<void> _load() async {
    final r = await AppDatabase.instance.clients();
    if (mounted) setState(() => _items = r);
  }

  List<Client> get _visibleItems {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((c) =>
      c.nom.toLowerCase().contains(q) ||
      c.telephone.toLowerCase().contains(q) ||
      c.ville.toLowerCase().contains(q)
    ).toList();
  }

  Future<void> _edit([Client? c]) async {
    final nom = TextEditingController(text: c?.nom ?? '');
    final tel = TextEditingController(text: c?.telephone ?? '');
    final ville = TextEditingController(text: c?.ville ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(c == null ? 'Nouveau client' : 'Modifier le client'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nom, textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nom')),
            TextField(controller: tel, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone')),
            TextField(controller: ville, textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ville')),
          ]),
        ),
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
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(c == null ? 'Client ajouté.' : 'Client modifié.')),
        );
      }
    }
    nom.dispose();
    tel.dispose();
    ville.dispose();
  }

  Future<void> _delete(Client c) async {
    try {
      await AppDatabase.instance.deleteClient(c.id!);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Impossible : ce client a des factures associées.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;
    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          SharkLogo(size: 32), SizedBox(width: 8), Text('Clients'),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        child: const Icon(Icons.person_add),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _filter = v),
            decoration: InputDecoration(
              hintText: 'Rechercher un client, téléphone ou ville',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _filter.isEmpty ? null : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _filter = '');
                },
                icon: const Icon(Icons.clear),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(_filter.isEmpty ? 'Aucun client' : 'Aucun résultat'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = items[i];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFE1DE),
                        foregroundColor: Color(0xFFC62828),
                        child: Icon(Icons.person),
                      ),
                      title: Text(c.nom),
                      subtitle: Text([c.telephone, c.ville]
                          .where((e) => e.isNotEmpty).join(' • ')),
                      onTap: () => _edit(c),
                      trailing: IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(c),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
