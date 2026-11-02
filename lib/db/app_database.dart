import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;
  Future<Database>? _opening;

  /// Emits whenever saved business data changes, so every open screen refreshes.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void _changed() => revision.value++;

  Future<Database> get db async {
    if (_db != null) return _db!;
    if (_opening != null) return _opening!;
    final opening = _open();
    _opening = opening;
    try {
      final database = await opening;
      _db = database;
      return database;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'plaques_pro.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE plate_types (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nom TEXT NOT NULL,
            prix REAL NOT NULL
          )''');
        await d.execute('''
          CREATE TABLE clients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nom TEXT NOT NULL,
            telephone TEXT,
            ville TEXT
          )''');
        await d.execute('''
          CREATE TABLE invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            numero TEXT NOT NULL UNIQUE,
            date TEXT NOT NULL,
            client_id INTEGER NOT NULL,
            taux_tva REAL NOT NULL DEFAULT 0,
            FOREIGN KEY (client_id) REFERENCES clients(id)
          )''');
        await d.execute('''
          CREATE TABLE invoice_lines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_id INTEGER NOT NULL,
            plate_type_id INTEGER,
            designation TEXT NOT NULL,
            quantite INTEGER NOT NULL,
            prix_unitaire REAL NOT NULL,
            FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
          )''');

        // Types de plaques par défaut (prix à modifier dans l'app)
        const defaults = [
          'Plaque normale',
          'Plaque réfléchissante',
          'Plaque longue',
          'Plaque large',
          'Plaque camion',
          'Plaque moto',
        ];
        for (final n in defaults) {
          await d.insert('plate_types', {'nom': n, 'prix': 0});
        }
      },
    );
  }

  // ---------- Types de plaques ----------
  Future<List<PlateType>> plateTypes() async {
    final d = await db;
    final r = await d.query('plate_types', orderBy: 'nom');
    return r.map(PlateType.fromMap).toList();
  }

  Future<void> savePlateType(PlateType t) async {
    final d = await db;
    if (t.id == null) {
      await d.insert('plate_types', {'nom': t.nom, 'prix': t.prix});
    } else {
      await d.update('plate_types', {'nom': t.nom, 'prix': t.prix},
          where: 'id = ?', whereArgs: [t.id]);
    }
    _changed();
  }

  Future<void> deletePlateType(int id) async {
    final d = await db;
    await d.delete('plate_types', where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  // ---------- Clients ----------
  Future<List<Client>> clients() async {
    final d = await db;
    final r = await d.query('clients', orderBy: 'nom');
    return r.map(Client.fromMap).toList();
  }

  Future<int> saveClient(Client c) async {
    final d = await db;
    final data = {'nom': c.nom, 'telephone': c.telephone, 'ville': c.ville};
    if (c.id == null) {
      final id = await d.insert('clients', data);
      _changed();
      return id;
    }
    await d.update('clients', data, where: 'id = ?', whereArgs: [c.id]);
    _changed();
    return c.id!;
  }

  Future<void> deleteClient(int id) async {
    final d = await db;
    await d.delete('clients', where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  // ---------- Factures ----------
  Future<String> nextInvoiceNumber() async {
    final d = await db;
    final year = DateTime.now().year;
    final r = await d.rawQuery(
        "SELECT COUNT(*) c FROM invoices WHERE numero LIKE 'F$year-%'");
    final n = (r.first['c'] as int) + 1;
    return 'F$year-${n.toString().padLeft(4, '0')}';
  }

  Future<int> saveInvoice(Invoice inv) async {
    final d = await db;
    final id = await d.transaction((txn) async {
      final id = await txn.insert('invoices', {
        'numero': inv.numero,
        'date': inv.date.toIso8601String(),
        'client_id': inv.client.id,
        'taux_tva': inv.tauxTva,
      });
      for (final l in inv.lignes) {
        await txn.insert('invoice_lines', {
          'invoice_id': id,
          'plate_type_id': l.plateTypeId,
          'designation': l.designation,
          'quantite': l.quantite,
          'prix_unitaire': l.prixUnitaire,
        });
      }
      return id;
    });
    _changed();
    return id;
  }

  /// Search clients, plate catalogue entries, invoices and invoice line labels.
  Future<List<GlobalSearchResult>> searchAll(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return [];
    final d = await db;
    final pattern = '%$query%';
    final results = <GlobalSearchResult>[];

    final clientRows = await d.query(
      'clients',
      where: 'nom LIKE ? OR telephone LIKE ? OR ville LIKE ?',
      whereArgs: [pattern, pattern, pattern],
      orderBy: 'nom',
      limit: 50,
    );
    results.addAll(clientRows.map((m) => GlobalSearchResult(
      category: 'Client',
      title: m['nom'] as String,
      subtitle: [m['telephone'], m['ville']]
          .whereType<String>()
          .where((v) => v.isNotEmpty)
          .join(' • '),
    )));

    final plateRows = await d.query(
      'plate_types',
      where: 'nom LIKE ?',
      whereArgs: [pattern],
      orderBy: 'nom',
      limit: 50,
    );
    results.addAll(plateRows.map((m) => GlobalSearchResult(
      category: 'Plaque',
      title: m['nom'] as String,
      subtitle: '${(m['prix'] as num).toStringAsFixed(2)} MAD HT',
    )));

    final invoiceRows = await d.rawQuery('''
      SELECT i.numero, i.date, c.nom AS client_nom,
             COALESCE(SUM(il.quantite * il.prix_unitaire), 0) AS total_ht
      FROM invoices i
      JOIN clients c ON c.id = i.client_id
      LEFT JOIN invoice_lines il ON il.invoice_id = i.id
      WHERE i.numero LIKE ?
         OR c.nom LIKE ?
         OR i.date LIKE ?
         OR EXISTS (
           SELECT 1 FROM invoice_lines x
           WHERE x.invoice_id = i.id AND x.designation LIKE ?
         )
      GROUP BY i.id
      ORDER BY i.date DESC
      LIMIT 50
    ''', [pattern, pattern, pattern, pattern]);
    results.addAll(invoiceRows.map((m) => GlobalSearchResult(
      category: 'Facture',
      title: '${m['numero']} — ${m['client_nom']}',
      subtitle: '${(m['total_ht'] as num).toStringAsFixed(2)} MAD HT',
    )));
    return results;
  }

  Future<List<Invoice>> invoices() async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT i.*, c.nom c_nom, c.telephone c_tel, c.ville c_ville
      FROM invoices i JOIN clients c ON c.id = i.client_id
      ORDER BY i.date DESC''');
    final out = <Invoice>[];
    for (final m in rows) {
      final lines = await d.query('invoice_lines',
          where: 'invoice_id = ?', whereArgs: [m['id']]);
      out.add(Invoice(
        id: m['id'] as int,
        numero: m['numero'] as String,
        date: DateTime.parse(m['date'] as String),
        tauxTva: (m['taux_tva'] as num).toDouble(),
        client: Client(
          id: m['client_id'] as int,
          nom: m['c_nom'] as String,
          telephone: (m['c_tel'] as String?) ?? '',
          ville: (m['c_ville'] as String?) ?? '',
        ),
        lignes: lines.map(InvoiceLine.fromMap).toList(),
      ));
    }
    return out;
  }
}
