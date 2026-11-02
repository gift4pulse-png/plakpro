import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/catalogue_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/invoice_screen.dart';
import 'screens/history_screen.dart';
import 'screens/search_screen.dart';
import 'screens/distribution_screen.dart';
import 'db/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  runApp(const PlaquesApp());
}

class PlaquesApp extends StatelessWidget {
  const PlaquesApp({super.key});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFC62828);
    final scheme = ColorScheme.fromSeed(
      seedColor: red,
      brightness: Brightness.light,
      primary: red,
      secondary: const Color(0xFF8E0000),
    );
    return MaterialApp(
      title: 'Aluminum Ainaki',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFFFF8F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: red,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: red.withValues(alpha: 0.14),
          labelTextStyle: WidgetStateProperty.resolveWith((states) =>
              TextStyle(
                color: states.contains(WidgetState.selected) ? red : Colors.black87,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
              )),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: red,
          foregroundColor: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: red,
            foregroundColor: Colors.white,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: red, width: 2),
          ),
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _arabic = false;

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.revision.addListener(_loadLanguage);
    _loadLanguage();
  }

  @override
  void dispose() {
    AppDatabase.instance.revision.removeListener(_loadLanguage);
    super.dispose();
  }

  Future<void> _loadLanguage() async {
    final language = await AppDatabase.instance.readSetting('language');
    if (mounted && _arabic != (language == 'ar')) {
      setState(() => _arabic = language == 'ar');
    }
  }

  static const _pages = <Widget>[
    DistributionScreen(),
    InvoiceScreen(),
    SearchScreen(),
    HistoryScreen(),
    CatalogueScreen(),
    ClientsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: Directionality(
        textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
        child: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.local_shipping_outlined), label: _arabic ? 'التوزيع' : 'Distribution'),
          NavigationDestination(icon: const Icon(Icons.receipt_long), label: _arabic ? 'الفاتورة' : 'Facture'),
          NavigationDestination(icon: const Icon(Icons.search), label: _arabic ? 'البحث' : 'Recherche'),
          NavigationDestination(icon: const Icon(Icons.history), label: _arabic ? 'السجل' : 'Historique'),
          NavigationDestination(icon: const Icon(Icons.view_list), label: _arabic ? 'الكتالوج' : 'Catalogue'),
          NavigationDestination(icon: const Icon(Icons.people), label: _arabic ? 'العملاء' : 'Clients'),
        ],
      )),
    );
  }
}
