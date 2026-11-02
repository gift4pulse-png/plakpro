import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/app_database.dart';
import '../models/models.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Invoice> _invoices = [];
  int _clientsCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        AppDatabase.instance.invoices(),
        AppDatabase.instance.clients(),
      ]);
      if (!mounted) return;
      setState(() {
        _invoices = results[0] as List<Invoice>;
        _clientsCount = (results[1] as List<Client>).length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = _invoices.where((i) =>
      i.date.year == now.year && i.date.month == now.month && i.date.day == now.day);
    final todayTotal = today.fold<double>(0, (sum, i) => sum + i.totalTTC);
    final allTotal = _invoices.fold<double>(0, (sum, i) => sum + i.totalTTC);
    final money = NumberFormat('#,##0.00', 'fr_FR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () { setState(() => _loading = true); _load(); },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF123B5D), Color(0xFF176B87)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('VOTRE ACTIVITÉ', style: TextStyle(
                          color: Colors.white70, fontSize: 11, letterSpacing: 1.5,
                          fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Text('${money.format(todayTotal)} MAD',
                          style: const TextStyle(color: Colors.white,
                            fontSize: 28, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('${today.length} facture(s) aujourd’hui',
                          style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _MetricCard(
                      icon: Icons.receipt_long_rounded,
                      label: 'Factures',
                      value: '${_invoices.length}',
                      tint: const Color(0xFFE8F1FF),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _MetricCard(
                      icon: Icons.people_alt_rounded,
                      label: 'Clients',
                      value: '$_clientsCount',
                      tint: const Color(0xFFE7F6F0),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  _MetricCard(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Total facturé (TTC)',
                    value: '${money.format(allTotal)} MAD',
                    tint: const Color(0xFFFFF2DF),
                    wide: true,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Factures récentes',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800)),
                      Text('${_invoices.length} au total',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_invoices.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18)),
                      child: const Column(children: [
                        Icon(Icons.receipt_long_outlined, size: 36),
                        SizedBox(height: 8),
                        Text('Aucune facture pour le moment'),
                        Text('Vos nouvelles factures apparaîtront ici.',
                          textAlign: TextAlign.center),
                      ]),
                    )
                  else
                    ..._invoices.take(5).map((invoice) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(Icons.description_outlined,
                            color: Theme.of(context).colorScheme.onPrimaryContainer),
                        ),
                        title: Text(invoice.numero,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${invoice.client.nom} • ${DateFormat('dd/MM/yyyy').format(invoice.date)}'),
                        trailing: Text('${money.format(invoice.totalTTC)} MAD',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    )),
                ],
              ),
            ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final bool wide;

  const _MetricCard({
    required this.icon, required this.label, required this.value,
    required this.tint, this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: const Color(0xFF173F5F)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800)),
            ],
          )),
        ]),
      ),
    );
  }
}
