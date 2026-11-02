import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/catalogue_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/invoice_screen.dart';
import 'screens/history_screen.dart';
import 'screens/search_screen.dart';

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

  static const _pages = <Widget>[
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Facture'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Recherche'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historique'),
          NavigationDestination(icon: Icon(Icons.view_list), label: 'Catalogue'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Clients'),
        ],
      ),
    );
  }
}
