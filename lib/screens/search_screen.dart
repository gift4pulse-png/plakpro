import 'package:flutter/material.dart';
import '../db/app_database.dart';
import '../models/models.dart';
import '../widgets/shark_logo.dart';

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

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.revision.addListener(_onDatabaseChanged);
  }

  @override
  void dispose() {
    AppDatabase.instance.revision.removeListener(_onDatabaseChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onDatabaseChanged() {
    if (_query.trim().isNotEmpty) _search(_query);
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
      case 'Client':
        return Icons.person_outline;
      case 'Plaque':
        return Icons.directions_car_outlined;
      default:
        return Icons.receipt_long;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          SharkLogo(size: 32), SizedBox(width: 8), Text('Recherche générale'),
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
              hintText: 'Nom, téléphone, plaque ou facture…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer',
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
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'Recherchez ici les clients, les types de plaques et les anciennes factures.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _results.isEmpty && !_loading
                  ? const Center(child: Text('Aucun résultat trouvé.'))
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
                          trailing: Chip(
                            label: Text(item.category),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide.none,
                            backgroundColor: const Color(0xFFFFE1DE),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
