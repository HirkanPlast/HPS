import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/expense.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('hps.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        category TEXT,
        unit TEXT NOT NULL,
        initial_stock REAL DEFAULT 0,
        min_stock REAL DEFAULT 0,
        buy_price REAL DEFAULT 0,
        sell_price REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        product_code TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        notes TEXT,
        created_by TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_code) REFERENCES products (code)
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_trans_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_trans_code ON transactions(product_code)');
    await db.execute('CREATE INDEX idx_trans_type ON transactions(type)');
    await db.execute('CREATE INDEX idx_exp_date ON expenses(date)');
  }

  // ========== PRODUCTS ==========

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getAllProducts({bool activeOnly = true}) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'code ASC',
    );
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<Product?> getProductByCode(String code) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'code = ?',
      whereArgs: [code],
    );
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ========== TRANSACTIONS ==========

  Future<int> insertTransaction(InventoryTransaction t) async {
    final db = await database;
    return await db.insert('transactions', t.toMap());
  }

  Future<List<InventoryTransaction>> getTransactions({
    String? fromDate,
    String? toDate,
    String? type,
    String? productCode,
    int limit = 500,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];

    if (fromDate != null) {
      where.add('date >= ?');
      args.add(fromDate);
    }
    if (toDate != null) {
      where.add('date <= ?');
      args.add(toDate);
    }
    if (type != null) {
      where.add('type = ?');
      args.add(type);
    }
    if (productCode != null) {
      where.add('product_code = ?');
      args.add(productCode);
    }

    final maps = await db.rawQuery('''
      SELECT t.*, p.name as product_name, p.unit
      FROM transactions t
      LEFT JOIN products p ON t.product_code = p.code
      ${where.isNotEmpty ? 'WHERE ${where.join(' AND ')}' : ''}
      ORDER BY t.date DESC, t.id DESC
      LIMIT $limit
    ''', args);

    return maps.map((m) => InventoryTransaction.fromMap(m)).toList();
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ========== STOCK CALCULATION ==========

  /// Current stock for a product = initial + sum of stock deltas
  Future<double> getCurrentStock(String productCode) async {
    final db = await database;
    final product = await getProductByCode(productCode);
    if (product == null) return 0;

    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(
          CASE 
            WHEN type = 'ورود' THEN quantity
            WHEN type = 'برگشت' THEN quantity
            WHEN type = 'فروش' THEN -quantity
            WHEN type = 'تعدیل' THEN quantity
            ELSE 0
          END
        ), 0) as delta
      FROM transactions
      WHERE product_code = ?
    ''', [productCode]);

    final delta = (result.first['delta'] as num?)?.toDouble() ?? 0;
    return product.initialStock + delta;
  }

  /// Full inventory list with current stock and status
  Future<List<Map<String, dynamic>>> getInventory() async {
    final products = await getAllProducts(activeOnly: true);
    final list = <Map<String, dynamic>>[];

    for (final p in products) {
      final current = await getCurrentStock(p.code);
      String status;
      if (current <= 0) {
        status = 'بدون موجودی';
      } else if (current < p.minStock) {
        status = 'کمبود';
      } else {
        status = 'تأمین';
      }

      list.add({
        'product': p,
        'current_stock': current,
        'status': status,
        'stock_value_buy': current * p.buyPrice,
        'stock_value_sell': current * p.sellPrice,
      });
    }
    return list;
  }

  // ========== EXPENSES ==========

  Future<int> insertExpense(Expense e) async {
    final db = await database;
    return await db.insert('expenses', e.toMap());
  }

  Future<List<Expense>> getExpenses({
    String? fromDate,
    String? toDate,
    String? category,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];

    if (fromDate != null) {
      where.add('date >= ?');
      args.add(fromDate);
    }
    if (toDate != null) {
      where.add('date <= ?');
      args.add(toDate);
    }
    if (category != null) {
      where.add('category = ?');
      args.add(category);
    }

    final maps = await db.query(
      'expenses',
      where: where.isNotEmpty ? where.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'date DESC, id DESC',
    );
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ========== DASHBOARD STATS ==========

  Future<Map<String, dynamic>> getDashboardStats({
    required String today,
    required String monthStart,
  }) async {
    final db = await database;

    // Sales today
    final salesToday = await db.rawQuery('''
      SELECT COALESCE(SUM(quantity * unit_price), 0) as total,
             COALESCE(SUM(quantity), 0) as qty
      FROM transactions
      WHERE type = 'فروش' AND date = ?
    ''', [today]);

    // Sales this month
    final salesMonth = await db.rawQuery('''
      SELECT COALESCE(SUM(quantity * unit_price), 0) as total,
             COALESCE(SUM(quantity), 0) as qty
      FROM transactions
      WHERE type = 'فروش' AND date >= ?
    ''', [monthStart]);

    // Expenses this month
    final expMonth = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM expenses
      WHERE date >= ?
    ''', [monthStart]);

    // Inventory summary
    final inventory = await getInventory();
    double stockValueBuy = 0;
    double stockValueSell = 0;
    int lowStock = 0;
    int outOfStock = 0;
    int okStock = 0;

    for (final item in inventory) {
      stockValueBuy += item['stock_value_buy'] as double;
      stockValueSell += item['stock_value_sell'] as double;
      final status = item['status'] as String;
      if (status == 'بدون موجودی') outOfStock++;
      else if (status == 'کمبود') lowStock++;
      else okStock++;
    }

    // COGS approximation this month (using current buy price)
    // Better would be FIFO, but for v1 we use average
    final cogsMonth = await db.rawQuery('''
      SELECT COALESCE(SUM(t.quantity * p.buy_price), 0) as total
      FROM transactions t
      JOIN products p ON t.product_code = p.code
      WHERE t.type = 'فروش' AND t.date >= ?
    ''', [monthStart]);

    final salesTotal = (salesMonth.first['total'] as num).toDouble();
    final cogs = (cogsMonth.first['total'] as num).toDouble();
    final expenses = (expMonth.first['total'] as num).toDouble();
    final grossProfit = salesTotal - cogs;
    final netProfit = grossProfit - expenses;

    return {
      'sales_today': (salesToday.first['total'] as num).toDouble(),
      'sales_today_qty': (salesToday.first['qty'] as num).toDouble(),
      'sales_month': salesTotal,
      'sales_month_qty': (salesMonth.first['qty'] as num).toDouble(),
      'expenses_month': expenses,
      'gross_profit_month': grossProfit,
      'net_profit_month': netProfit,
      'stock_value_buy': stockValueBuy,
      'stock_value_sell': stockValueSell,
      'products_ok': okStock,
      'products_low': lowStock,
      'products_out': outOfStock,
      'total_products': inventory.length,
    };
  }


  /// Replace ledger records while preserving the existing product catalogue.
  Future<void> importOperationalData({
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> expenses,
    bool resetInitialStock = false,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final products = await txn.query('products', columns: ['code']);
      final codes = products.map((p) => p['code'] as String).toSet();
      for (final t in transactions) {
        final code = t['product_code'] as String;
        if (!codes.contains(code)) {
          throw Exception('کد کالای ناموجود: $code');
        }
      }
      await txn.delete('transactions');
      await txn.delete('expenses');
      if (resetInitialStock) {
        // A full ledger import already contains stock movements; do not add seeded opening stock again.
        await txn.update('products', {'initial_stock': 0});
      }
      for (final t in transactions) {
        await txn.insert('transactions', t);
      }
      for (final e in expenses) {
        await txn.insert('expenses', e);
      }
    });
  }

  // ========== BACKUP / RESTORE ==========

  Future<Map<String, dynamic>> exportAllData() async {
    final products = await getAllProducts(activeOnly: false);
    final transactions = await getTransactions(limit: 100000);
    final expenses = await getExpenses();

    return {
      'version': '1.0.1',
      'exported_at': DateTime.now().toIso8601String(),
      'products': products.map((p) => p.toMap()).toList(),
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'expenses': expenses.map((e) => e.toMap()).toList(),
    };
  }

  /// Full restore from backup JSON (products + transactions + expenses)
  Future<void> importAllData(Map<String, dynamic> data, {bool clearFirst = true}) async {
    final db = await database;
    await db.transaction((txn) async {
      if (clearFirst) {
        await txn.delete('transactions');
        await txn.delete('expenses');
        await txn.delete('products');
      }

      final products = data['products'] as List? ?? [];
      for (final p in products) {
        final map = Map<String, dynamic>.from(p)..remove('id');
        // Ensure required fields
        map['is_active'] = map['is_active'] ?? 1;
        await txn.insert('products', map, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final transactions = data['transactions'] as List? ?? [];
      for (final t in transactions) {
        final map = Map<String, dynamic>.from(t)..remove('id');
        await txn.insert('transactions', map);
      }

      final expenses = data['expenses'] as List? ?? [];
      for (final e in expenses) {
        final map = Map<String, dynamic>.from(e)..remove('id');
        await txn.insert('expenses', map);
      }
    });
  }

  /// Seed only products from the built-in seed_products.json (or provided list)
  Future<int> seedProducts(List<Map<String, dynamic>> products, {bool clearExisting = false}) async {
    final db = await database;
    int count = 0;
    await db.transaction((txn) async {
      if (clearExisting) {
        await txn.delete('products');
      }
      for (final p in products) {
        final map = Map<String, dynamic>.from(p)..remove('id');
        map['is_active'] = map['is_active'] ?? 1;
        try {
          await txn.insert('products', map, conflictAlgorithm: ConflictAlgorithm.ignore);
          count++;
        } catch (_) {
          // skip duplicates
        }
      }
    });
    return count;
  }

  /// Check if products table is empty
  Future<bool> isProductsEmpty() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM products');
    return ((result.first['c'] as int?) ?? 0) == 0;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
