import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../ui.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<Rental>> _future;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _future = _load();
      _initialized = true;
    }
  }

  Future<List<Rental>> _load() async {
    final scope = AppScope.of(context);
    final token = scope.session.token;
    if (token == null) throw ApiException('Login required.');
    return scope.api.fetchRentals(token);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Rental>>(
      future: _future,
      builder: (context, snapshot) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kRentGoPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: kRentGoPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ride history', style: Theme.of(context).textTheme.titleLarge),
                        Text(
                          'Every completed or ongoing rental appears here.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kRentGoText.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (snapshot.hasError)
                AppPanel(
                  child: Text(
                    snapshot.error.toString(),
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                )
              else if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if ((snapshot.data ?? const <Rental>[]).isEmpty)
                const _EmptyHistory()
              else
                ...snapshot.data!.map(
                  (rental) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _HistoryCard(rental: rental),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.rental});

  final Rental rental;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(rental.status);

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  rental.vehicleLabel == 'Bike' ? Icons.pedal_bike_rounded : Icons.electric_scooter_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rental.vehicleLabel, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      formatDateTime(rental.startTime),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kRentGoText.withValues(alpha: 0.65)),
                    ),
                  ],
                ),
              ),
              StatusPill(label: statusLabel(rental.status), color: color),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              MetricTile(
                value: formatMinutes(rental.durationMinutes),
                label: 'Duration',
                icon: Icons.timer_rounded,
                color: kRentGoPrimary,
              ),
              const SizedBox(width: 12),
              MetricTile(
                value: formatMoney(rental.totalPrice),
                label: 'Total',
                icon: Icons.payments_rounded,
                color: kRentGoAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        children: [
          const Icon(Icons.hourglass_empty_rounded, size: 42, color: kRentGoPrimary),
          const SizedBox(height: 12),
          Text('No rides yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Your trips will appear here after you start and end a rental.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kRentGoText.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
  }
}
