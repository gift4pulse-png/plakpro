import 'package:flutter/material.dart';
import '../db/app_database.dart';
import '../models/models.dart';
import '../widgets/shark_logo.dart';

class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({super.key});
  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  List<PlateType> _items = [];
  String _filter = '';
  bool _arabic = false;
  String tr(String fr, String ar) => _arabic ? ar : fr;

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
    final r = await AppDatabase.instance.plateTypes();
    final language = await AppDatabase.instance.readSetting('language');
    if (mounted) setState(() { _items = r; _arabic = language == 'ar'; });
  }

  List<PlateType> get _visibleItems {
    final q = _filter.trim().toLowerCase();
    return q.isEmpty ? _items : _items.where((t) => t.nom.toLowerCase().contains(q)).toList();
  }

  Future<void> _edit([PlateType? t]) async {
    final nom = TextEditingController(text: t?.nom ?? '');
    final prix = TextEditingController(text: t == null ? '' : t.prix.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t == null ? tr('Nouveau type', 'نوع جديد') : tr('Modifier le type', 'تعديل النوع')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nom, textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tr('Nom', 'الاسم'))),
          TextField(
            controller: prix,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: tr('Prix de vente HT (MAD)', 'ثمن البيع بدون ضريبة (درهم)')),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Annuler', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Enregistrer', 'حفظ'))),
        ],
      ),
    );
    if (ok == true && nom.text.trim().isNotEmpty) {
      await AppDatabase.instance.savePlateType(PlateType(
        id: t?.id,
        nom: nom.text.trim(),
        prix: double.tryParse(prix.text.replaceAll(',', '.')) ?? 0,
      ));
      await _load();
    }
    nom.dispose();
    prix.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;
    return Directionality(textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr, child: Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const SharkLogo(size: 32), const SizedBox(width: 8), Text(tr('Catalogue des plaques', 'كتالوج السلع')),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        child: const Icon(Icons.add),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _filter = v),
            decoration: InputDecoration(
              hintText: tr('Rechercher un type de plaque', 'البحث عن نوع السلعة'),
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(_filter.isEmpty ? tr('Aucun type de plaque', 'ما كاين حتى نوع') : tr('Aucun résultat', 'ما كايناش نتائج')))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = items[i];
                    return ListTile(
                      title: Text(t.nom),
                      subtitle: Text('${t.prix.toStringAsFixed(2)} MAD HT'),
                      onTap: () => _edit(t),
                      trailing: IconButton(
                        tooltip: tr('Supprimer', 'حذف'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await AppDatabase.instance.deletePlateType(t.id!);
                          await _load();
                        },
                      ),
                    );
                  },
                ),
        ),
      ]),
    ));
  }
}
