import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get db async => _db ??= await _open();

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
  }

  Future<void> deletePlateType(int id) async {
    final d = await db;
    await d.delete('plate_types', where: 'id = ?', whereArgs: [id]);
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
    if (c.id == null) return d.insert('clients', data);
    await d.update('clients', data, where: 'id = ?', whereArgs: [c.id]);
    return c.id!;
  }

  Future<void> deleteClient(int id) async {
    final d = await db;
    await d.delete('clients', where: 'id = ?', whereArgs: [id]);
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
    return d.transaction((txn) async {
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
