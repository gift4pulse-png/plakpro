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
      version: 3,
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
        await _createDistributionTables(d);
      },
      onUpgrade: (d, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createDistributionTables(d);
        if (oldVersion < 3) {
          await _createDistributionExpensesTable(d);
          final columns = await d.rawQuery('PRAGMA table_info(distribution_sale_lines)');
          if (columns.isNotEmpty && !columns.any((c) => c['name'] == 'purchase_unit_cost')) {
            await d.execute('ALTER TABLE distribution_sale_lines ADD COLUMN purchase_unit_cost REAL NOT NULL DEFAULT 0');
          }
        }
      },
    );
  }

  /// Additive migration: legacy clients, catalogue and invoices are untouched.
  Future<void> _createDistributionTables(DatabaseExecutor d) async {
    await d.execute('''CREATE TABLE IF NOT EXISTS distribution_products (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      variant TEXT NOT NULL DEFAULT '', pieces_per_pack INTEGER,
      purchase_price REAL NOT NULL DEFAULT 0, sale_price REAL NOT NULL DEFAULT 0,
      active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL)''');
    await d.execute('''CREATE TABLE IF NOT EXISTS distribution_sales (
      id INTEGER PRIMARY KEY AUTOINCREMENT, client_id INTEGER,
      client_name_snapshot TEXT NOT NULL, city_snapshot TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL, total_amount REAL NOT NULL,
      payment_method TEXT NOT NULL, payment_reference TEXT NOT NULL DEFAULT '',
      note TEXT NOT NULL DEFAULT '',
      FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL)''');
    await d.execute('''CREATE TABLE IF NOT EXISTS distribution_sale_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER NOT NULL, product_id INTEGER,
      product_name_snapshot TEXT NOT NULL, variant_snapshot TEXT NOT NULL DEFAULT '',
      quantity_pieces INTEGER NOT NULL, pack_count INTEGER NOT NULL DEFAULT 0,
      loose_count INTEGER NOT NULL DEFAULT 0, unit_price REAL NOT NULL,
      purchase_unit_cost REAL NOT NULL DEFAULT 0, line_total REAL NOT NULL,
      FOREIGN KEY (sale_id) REFERENCES distribution_sales(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES distribution_products(id) ON DELETE SET NULL)''');
    await d.execute('''CREATE TABLE IF NOT EXISTS distribution_stock_moves (
      id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL,
      from_location TEXT NOT NULL DEFAULT '', to_location TEXT NOT NULL DEFAULT '',
      quantity_pieces INTEGER NOT NULL CHECK(quantity_pieces > 0),
      pack_count INTEGER NOT NULL DEFAULT 0, loose_count INTEGER NOT NULL DEFAULT 0,
      sale_id INTEGER, created_at TEXT NOT NULL, note TEXT NOT NULL DEFAULT '',
      FOREIGN KEY (product_id) REFERENCES distribution_products(id),
      FOREIGN KEY (sale_id) REFERENCES distribution_sales(id) ON DELETE CASCADE)''');
    await d.execute('''CREATE TABLE IF NOT EXISTS distribution_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER NOT NULL,
      amount REAL NOT NULL CHECK(amount > 0), method TEXT NOT NULL,
      reference TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'confirmed',
      created_at TEXT NOT NULL, note TEXT NOT NULL DEFAULT '',
      FOREIGN KEY (sale_id) REFERENCES distribution_sales(id) ON DELETE CASCADE)''');
    await d.execute('''CREATE TABLE IF NOT EXISTS app_settings (
      setting_key TEXT PRIMARY KEY, setting_value TEXT NOT NULL)''');
    await _createDistributionExpensesTable(d);
    await d.execute('CREATE INDEX IF NOT EXISTS idx_distribution_moves_product ON distribution_stock_moves(product_id)');
    await d.execute('CREATE INDEX IF NOT EXISTS idx_distribution_sales_date ON distribution_sales(created_at)');
    await d.execute('CREATE INDEX IF NOT EXISTS idx_distribution_payments_sale ON distribution_payments(sale_id)');
  }

  Future<void> _createDistributionExpensesTable(DatabaseExecutor d) async {
    await d.execute('''CREATE TABLE IF NOT EXISTS distribution_expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT, category TEXT NOT NULL,
      amount REAL NOT NULL CHECK(amount > 0), created_at TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '')''');
    await d.execute('CREATE INDEX IF NOT EXISTS idx_distribution_expenses_date ON distribution_expenses(created_at)');
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
      id: m['id'] as int,
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
      id: m['id'] as int,
      title: m['nom'] as String,
      subtitle: '${(m['prix'] as num).toStringAsFixed(2)} MAD HT',
    )));

    final distributionProductsRows = await d.query(
      'distribution_products', where: 'active = 1 AND (name LIKE ? OR variant LIKE ?)',
      whereArgs: [pattern, pattern], orderBy: 'name', limit: 50);
    results.addAll(distributionProductsRows.map((m) => GlobalSearchResult(
      category: 'Stock', id: m['id'] as int, title: '${m['name']}${(m['variant'] as String).isEmpty ? '' : ' — ${m['variant']}'}',
      subtitle: '${(m['sale_price'] as num).toStringAsFixed(2)} MAD / pièce')));

    final distributionSalesRows = await d.query('distribution_sales',
      where: 'client_name_snapshot LIKE ? OR city_snapshot LIKE ? OR payment_reference LIKE ? OR CAST(id AS TEXT) LIKE ?',
      whereArgs: [pattern, pattern, pattern, pattern], orderBy: 'created_at DESC', limit: 50);
    results.addAll(distributionSalesRows.map((m) => GlobalSearchResult(
      category: 'Vente', id: m['id'] as int, title: '#${m['id']} — ${m['client_name_snapshot']}',
      subtitle: '${(m['total_amount'] as num).toStringAsFixed(2)} MAD')));

    final invoiceRows = await d.rawQuery('''
      SELECT i.id, i.numero, i.date, c.nom AS client_nom,
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
      id: m['id'] as int,
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
  // ---------- Distribution / stock / customer collection ----------
  static const String depotLocation = 'depot';
  static const String vehicleLocation = 'vehicle';

  Future<List<DistributionProduct>> distributionProducts({bool includeInactive = false}) async {
    final d = await db;
    final rows = await d.query('distribution_products',
      where: includeInactive ? null : 'active = 1',
      orderBy: 'name COLLATE NOCASE, variant COLLATE NOCASE');
    return rows.map(DistributionProduct.fromMap).toList();
  }

  Future<int> saveDistributionProduct(DistributionProduct p) async {
    if (p.name.trim().isEmpty) throw ArgumentError('Product name is required.');
    if (p.piecesPerPack != null && p.piecesPerPack! <= 0) throw ArgumentError('Pack size must be positive.');
    if (!p.purchasePrice.isFinite || !p.salePrice.isFinite || p.purchasePrice < 0 || p.salePrice < 0) {
      throw ArgumentError('Prices must be finite and cannot be negative.');
    }
    final d = await db;
    final values = <String, Object?>{
      'name': p.name.trim(), 'variant': p.variant.trim(), 'pieces_per_pack': p.piecesPerPack,
      'purchase_price': p.purchasePrice, 'sale_price': p.salePrice, 'active': p.active ? 1 : 0,
    };
    final id = p.id == null
      ? await d.insert('distribution_products', {...values, 'created_at': DateTime.now().toIso8601String()})
      : p.id!;
    if (p.id != null) await d.update('distribution_products', values, where: 'id = ?', whereArgs: [p.id]);
    _changed();
    return id;
  }

  Future<Map<int, int>> distributionBalances(String location) async {
    if (location != depotLocation && location != vehicleLocation) throw ArgumentError('Unknown location.');
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT p.id, COALESCE(SUM(CASE WHEN m.to_location = ? THEN m.quantity_pieces
        WHEN m.from_location = ? THEN -m.quantity_pieces ELSE 0 END), 0) AS balance
      FROM distribution_products p LEFT JOIN distribution_stock_moves m ON m.product_id = p.id
      GROUP BY p.id''', [location, location]);
    return {for (final r in rows) r['id'] as int: (r['balance'] as num).toInt()};
  }

  Future<List<DistributionStock>> distributionStock() async {
    final products = await distributionProducts(includeInactive: true);
    final depot = await distributionBalances(depotLocation);
    final vehicle = await distributionBalances(vehicleLocation);
    return products.map((p) => DistributionStock(product: p,
      depotPieces: depot[p.id] ?? 0, vehiclePieces: vehicle[p.id] ?? 0)).toList();
  }

  Future<void> receiveIntoDepot({required DistributionProduct product, required int packs,
      required int loosePieces, String note = ''}) async {
    final qty = product.piecesFor(packs, loosePieces);
    if (qty <= 0) throw ArgumentError('Enter a positive quantity.');
    final d = await db;
    await d.insert('distribution_stock_moves', {'product_id': product.id, 'from_location': '',
      'to_location': depotLocation, 'quantity_pieces': qty, 'pack_count': packs,
      'loose_count': loosePieces, 'created_at': DateTime.now().toIso8601String(), 'note': note});
    _changed();
  }

  Future<void> _transferStock({required DistributionProduct product, required int packs,
      required int loosePieces, required String from, required String to, String note = ''}) async {
    final qty = product.piecesFor(packs, loosePieces);
    if (qty <= 0) throw ArgumentError('Enter a positive quantity.');
    final d = await db;
    await d.transaction((txn) async {
      final rows = await txn.rawQuery('''SELECT COALESCE(SUM(CASE WHEN to_location = ? THEN quantity_pieces
        WHEN from_location = ? THEN -quantity_pieces ELSE 0 END), 0) AS balance
        FROM distribution_stock_moves WHERE product_id = ?''', [from, from, product.id]);
      final balance = (rows.first['balance'] as num).toInt();
      if (balance < qty) throw StateError('Insufficient stock. Available: $balance pieces.');
      await txn.insert('distribution_stock_moves', {'product_id': product.id, 'from_location': from,
        'to_location': to, 'quantity_pieces': qty, 'pack_count': packs, 'loose_count': loosePieces,
        'created_at': DateTime.now().toIso8601String(), 'note': note});
    });
    _changed();
  }

  Future<void> loadVehicle({required DistributionProduct product, required int packs,
      required int loosePieces, String note = ''}) => _transferStock(
        product: product, packs: packs, loosePieces: loosePieces,
        from: depotLocation, to: vehicleLocation, note: note);

  Future<void> returnVehicleToDepot({required DistributionProduct product, required int packs,
      required int loosePieces, String note = ''}) => _transferStock(
        product: product, packs: packs, loosePieces: loosePieces,
        from: vehicleLocation, to: depotLocation, note: note);

  Future<int> createDistributionSale({required Client? client, required String walkInName,
      required List<DistributionSaleLineInput> lines, required double paidAmount,
      required String paymentMethod, String paymentReference = '', String note = ''}) async {
    if (lines.isEmpty) throw ArgumentError('Add at least one product.');
    for (final line in lines) {
      if (line.product.id == null || line.quantityPieces <= 0 || !line.unitPrice.isFinite || line.unitPrice < 0) {
        throw ArgumentError('Invalid product line.');
      }
    }
    final total = lines.fold<double>(0, (sum, line) => sum + line.total);
    if (!total.isFinite || !paidAmount.isFinite || total <= 0 || paidAmount < 0 || paidAmount > total) {
      throw ArgumentError('Invalid sale or payment amount.');
    }
    final clientName = client?.nom ?? walkInName.trim();
    if (clientName.isEmpty) throw ArgumentError('Choose a client or enter a name.');
    final d = await db;
    final saleId = await d.transaction((txn) async {
      // Check every product before writing anything, so the sale is atomic.
      final requested = <int, int>{};
      final productById = <int, DistributionProduct>{};
      for (final line in lines) {
        final productId = line.product.id!;
        requested.update(productId, (value) => value + line.quantityPieces,
            ifAbsent: () => line.quantityPieces);
        productById[productId] = line.product;
      }
      for (final entry in requested.entries) {
        final rows = await txn.rawQuery('''SELECT COALESCE(SUM(CASE WHEN to_location = ? THEN quantity_pieces
          WHEN from_location = ? THEN -quantity_pieces ELSE 0 END), 0) AS balance
          FROM distribution_stock_moves WHERE product_id = ?''',
          [vehicleLocation, vehicleLocation, entry.key]);
        if ((rows.first['balance'] as num).toInt() < entry.value) {
          throw StateError('Insufficient vehicle stock for ${productById[entry.key]!.name}.');
        }
      }
      final id = await txn.insert('distribution_sales', {'client_id': client?.id,
        'client_name_snapshot': clientName, 'city_snapshot': client?.ville ?? '',
        'created_at': DateTime.now().toIso8601String(), 'total_amount': total,
        'payment_method': paymentMethod, 'payment_reference': paymentReference.trim(), 'note': note.trim()});
      for (final line in lines) {
        await txn.insert('distribution_sale_lines', {'sale_id': id, 'product_id': line.product.id,
          'product_name_snapshot': line.product.name, 'variant_snapshot': line.product.variant,
          'quantity_pieces': line.quantityPieces, 'pack_count': line.packs, 'loose_count': line.loosePieces,
          'unit_price': line.unitPrice, 'purchase_unit_cost': line.product.purchasePrice,
          'line_total': line.total});
        await txn.insert('distribution_stock_moves', {'product_id': line.product.id,
          'from_location': vehicleLocation, 'to_location': 'sold', 'quantity_pieces': line.quantityPieces,
          'pack_count': line.packs, 'loose_count': line.loosePieces, 'sale_id': id,
          'created_at': DateTime.now().toIso8601String(), 'note': 'Distribution sale #$id'});
      }
      if (paidAmount > 0) {
        await txn.insert('distribution_payments', {'sale_id': id, 'amount': paidAmount,
          'method': paymentMethod, 'reference': paymentReference.trim(),
          'status': paymentMethod == 'transfer_pending' ? 'pending' : 'confirmed',
          'created_at': DateTime.now().toIso8601String(), 'note': ''});
      }
      return id;
    });
    _changed();
    return saleId;
  }

  Future<void> addDistributionPayment({required int saleId, required double amount,
      required String method, String reference = '', String note = ''}) async {
    if (!amount.isFinite || amount <= 0) throw ArgumentError('Payment must be positive.');
    final d = await db;
    await d.transaction((txn) async {
      final sales = await txn.query('distribution_sales', where: 'id = ?', whereArgs: [saleId]);
      if (sales.isEmpty) throw StateError('Sale not found.');
      final total = (sales.first['total_amount'] as num).toDouble();
      final sums = await txn.rawQuery('''SELECT
        COALESCE(SUM(CASE WHEN status = 'confirmed' THEN amount ELSE 0 END), 0) paid,
        COALESCE(SUM(CASE WHEN status = 'pending' THEN amount ELSE 0 END), 0) pending
        FROM distribution_payments WHERE sale_id = ?''', [saleId]);
      final reserved = (sums.first['paid'] as num).toDouble() + (sums.first['pending'] as num).toDouble();
      if (reserved + amount > total + 0.0001) throw StateError('Payment exceeds remaining balance.');
      await txn.insert('distribution_payments', {'sale_id': saleId, 'amount': amount,
        'method': method, 'reference': reference.trim(),
        'status': method == 'transfer_pending' ? 'pending' : 'confirmed',
        'created_at': DateTime.now().toIso8601String(), 'note': note.trim()});
    });
    _changed();
  }

  Future<void> confirmDistributionTransfer(int paymentId) async {
    final d = await db;
    await d.update('distribution_payments', {'status': 'confirmed'},
      where: 'id = ? AND status = ?', whereArgs: [paymentId, 'pending']);
    _changed();
  }

  Future<List<Map<String, Object?>>> distributionPaymentsForSale(int saleId) async {
    final d = await db;
    return d.query('distribution_payments', where: 'sale_id = ?', whereArgs: [saleId], orderBy: 'created_at DESC');
  }

  Future<List<Map<String, Object?>>> distributionLinesForSale(int saleId) async {
    final d = await db;
    return d.query('distribution_sale_lines', where: 'sale_id = ?', whereArgs: [saleId], orderBy: 'id');
  }

  Future<List<DistributionSaleSummary>> distributionSales() async {
    final d = await db;
    final rows = await d.rawQuery('''SELECT s.*,
      COALESCE(SUM(CASE WHEN p.status = 'confirmed' THEN p.amount ELSE 0 END), 0) confirmed_paid,
      COALESCE(SUM(CASE WHEN p.status = 'pending' THEN p.amount ELSE 0 END), 0) pending_transfer
      FROM distribution_sales s LEFT JOIN distribution_payments p ON p.sale_id = s.id
      GROUP BY s.id ORDER BY s.created_at DESC''');
    return rows.map((m) => DistributionSaleSummary(id: m['id'] as int,
      clientName: m['client_name_snapshot'] as String, city: (m['city_snapshot'] as String?) ?? '',
      date: DateTime.parse(m['created_at'] as String), total: (m['total_amount'] as num).toDouble(),
      confirmedPaid: (m['confirmed_paid'] as num).toDouble(),
      pendingTransfer: (m['pending_transfer'] as num).toDouble(),
      paymentMethod: m['payment_method'] as String)).toList();
  }

  Future<void> saveDistributionExpense({required String category, required double amount, String note = ''}) async {
    if (category.trim().isEmpty || !amount.isFinite || amount <= 0) throw ArgumentError('Enter an expense category and a positive amount.');
    final d = await db;
    await d.insert('distribution_expenses', {'category': category.trim(), 'amount': amount,
      'created_at': DateTime.now().toIso8601String(), 'note': note.trim()});
    _changed();
  }

  Future<Map<String, double>> distributionFinancialSummary() async {
    final d = await db;
    final sales = await d.rawQuery('''SELECT
      COALESCE(SUM(line_total), 0) AS revenue,
      COALESCE(SUM(quantity_pieces * purchase_unit_cost), 0) AS cost
      FROM distribution_sale_lines''');
    final expenses = await d.rawQuery('SELECT COALESCE(SUM(amount), 0) AS total FROM distribution_expenses');
    return {
      'revenue': (sales.first['revenue'] as num).toDouble(),
      'cost': (sales.first['cost'] as num).toDouble(),
      'expenses': (expenses.first['total'] as num).toDouble(),
    };
  }

  Future<List<Map<String, Object?>>> distributionExpenses() async {
    final d = await db;
    return d.query('distribution_expenses', orderBy: 'created_at DESC', limit: 100);
  }

  Future<void> saveSetting(String key, String value) async {
    final d = await db;
    await d.insert('app_settings', {'setting_key': key, 'setting_value': value},
      conflictAlgorithm: ConflictAlgorithm.replace);
    _changed();
  }

  Future<String?> readSetting(String key) async {
    final d = await db;
    final rows = await d.query('app_settings', columns: ['setting_value'],
      where: 'setting_key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['setting_value'] as String;
  }

}
