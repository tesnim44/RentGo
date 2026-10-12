import 'package:flutter/material.dart';

import '../ui.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  static const _weeklyIncome = [2.8, 3.5, 3.1, 4.4, 5.2, 6.1, 5.6];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _DashboardHeader(wide: wide),
            const SizedBox(height: 18),
            _MetricGrid(wide: wide),
            const SizedBox(height: 18),
            if (wide)
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _IncomePanel(values: _weeklyIncome)),
                  SizedBox(width: 18),
                  Expanded(flex: 2, child: _ParkingPanel()),
                ],
              )
            else ...[
              const _IncomePanel(values: _weeklyIncome),
              const SizedBox(height: 18),
              const _ParkingPanel(),
            ],
            const SizedBox(height: 18),
            if (wide)
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _FleetPanel()),
                  SizedBox(width: 18),
                  Expanded(child: _UsersPanel()),
                ],
              )
            else ...[
              const _FleetPanel(),
              const SizedBox(height: 18),
              const _UsersPanel(),
            ],
          ],
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return AppHeroFrame(
      child: Padding(
        padding: EdgeInsets.all(wide ? 28 : 22),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Admin console',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'RentGo operations',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          height: 1.0,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Track income, parking capacity, fleet health and user activity from one organized view.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.84),
                        ),
                  ),
                ],
              ),
            ),
            if (wide) ...[
              const SizedBox(width: 24),
              Container(
                width: 156,
                height: 156,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 112,
                      height: 112,
                      child: CircularProgressIndicator(
                        value: 0.78,
                        strokeWidth: 12,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        color: const Color(0xFFFFB84D),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '78%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'utilization',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      const _MetricData(
        title: 'Income',
        value: '5,620 TND',
        detail: '+18% this week',
        icon: Icons.payments_rounded,
        color: Color(0xFF0F766E),
      ),
      const _MetricData(
        title: 'Parking capacity',
        value: '146 / 188',
        detail: '42 places open',
        icon: Icons.local_parking_rounded,
        color: Color(0xFF2563EB),
      ),
      const _MetricData(
        title: 'Users',
        value: '12,840',
        detail: '436 active today',
        icon: Icons.groups_rounded,
        color: Color(0xFF7C3AED),
      ),
      const _MetricData(
        title: 'Fleet online',
        value: '92%',
        detail: '128 vehicles live',
        icon: Icons.electric_scooter_rounded,
        color: Color(0xFFF59E0B),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 4 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: wide ? 1.55 : 1.28,
      ),
      itemBuilder: (context, index) => _AdminMetricCard(data: metrics[index]),
    );
  }
}

class _AdminMetricCard extends StatelessWidget {
  const _AdminMetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(data.icon, color: data.color, size: 22),
              ),
              const Spacer(),
              Icon(Icons.trending_up_rounded, color: data.color, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            data.title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: kRentGoText.withValues(alpha: 0.66),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            data.detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: data.color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomePanel extends StatelessWidget {
  const _IncomePanel({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Income',
            subtitle: 'Daily rental revenue in thousands of TND.',
            trailing: StatusPill(label: 'Live', color: kRentGoPrimary),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final item in values.indexed) ...[
                  Expanded(
                    child: _RevenueBar(
                      label: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][item.$1],
                      value: item.$2,
                      maxValue: 6.4,
                    ),
                  ),
                  if (item.$1 != values.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SmallStat(
                  label: 'Average ride',
                  value: '4.8 TND',
                  icon: Icons.route_rounded,
                  color: kRentGoPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SmallStat(
                  label: 'Refunds',
                  value: '86 TND',
                  icon: Icons.keyboard_return_rounded,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueBar extends StatelessWidget {
  const _RevenueBar({
    required this.label,
    required this.value,
    required this.maxValue,
  });

  final String label;
  final double value;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final heightFactor = (value / maxValue).clamp(0.08, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          value.toStringAsFixed(1),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: kRentGoText.withValues(alpha: 0.58),
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: heightFactor,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: kRentGoText.withValues(alpha: 0.62),
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _ParkingPanel extends StatelessWidget {
  const _ParkingPanel();

  @override
  Widget build(BuildContext context) {
    const zones = [
      _ZoneData('Medina', 0.84, Color(0xFF0F766E), '42 / 50'),
      _ZoneData('Corniche', 0.72, Color(0xFF2563EB), '36 / 50'),
      _ZoneData('Kantaoui', 0.91, Color(0xFFF59E0B), '41 / 45'),
      _ZoneData('Station Nord', 0.58, Color(0xFF7C3AED), '27 / 43'),
    ];

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Parking capacity',
            subtitle: 'Occupancy by operating zone.',
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 166,
              height: 166,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 0.78,
                    strokeWidth: 18,
                    backgroundColor: const Color(0xFFE6EFEF),
                    color: kRentGoPrimary,
                    strokeCap: StrokeCap.round,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '78%',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        'occupied',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: kRentGoText.withValues(alpha: 0.62),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          for (final zone in zones) ...[
            _ZoneRow(zone: zone),
            if (zone != zones.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({required this.zone});

  final _ZoneData zone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                zone.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            Text(
              zone.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kRentGoText.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: zone.value,
            backgroundColor: zone.color.withValues(alpha: 0.12),
            color: zone.color,
          ),
        ),
      ],
    );
  }
}

class _FleetPanel extends StatelessWidget {
  const _FleetPanel();

  @override
  Widget build(BuildContext context) {
    const items = [
      _ActivityData('Battery swap team dispatched', 'Kantaoui zone', Icons.battery_charging_full_rounded, Color(0xFFF59E0B)),
      _ActivityData('12 scooters returned', 'Medina station', Icons.assignment_return_rounded, Color(0xFF0F766E)),
      _ActivityData('Maintenance queue updated', '6 vehicles pending', Icons.build_circle_rounded, Color(0xFFDC2626)),
      _ActivityData('New parking bay enabled', 'Corniche east', Icons.local_parking_rounded, Color(0xFF2563EB)),
    ];

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Fleet activity',
            subtitle: 'Recent operational events.',
          ),
          const SizedBox(height: 14),
          for (final item in items) ...[
            _ActivityRow(item: item),
            if (item != items.last) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final _ActivityData item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(item.icon, color: item.color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                item.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kRentGoText.withValues(alpha: 0.6),
                    ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: kRentGoText.withValues(alpha: 0.34)),
      ],
    );
  }
}

class _UsersPanel extends StatelessWidget {
  const _UsersPanel();

  @override
  Widget build(BuildContext context) {
    const users = [
      _UserData('Amine Trabelsi', 'Verified rider', '28 rides', Color(0xFF0F766E)),
      _UserData('Nour Jaziri', 'Wallet low', '3.200 TND', Color(0xFFF59E0B)),
      _UserData('Meriem Saidi', 'Support open', 'Ticket #184', Color(0xFFDC2626)),
      _UserData('Youssef Ben Ali', 'New account', 'Today', Color(0xFF2563EB)),
    ];

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Users',
            subtitle: 'Accounts needing a quick admin glance.',
            trailing: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.manage_accounts_rounded, size: 18),
              label: const Text('Manage'),
            ),
          ),
          const SizedBox(height: 14),
          for (final user in users) ...[
            _UserRow(user: user),
            if (user != users.last) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  final _UserData user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: user.color.withValues(alpha: 0.14),
          child: Text(
            user.name.characters.first,
            style: TextStyle(
              color: user.color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                user.status,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kRentGoText.withValues(alpha: 0.58),
                    ),
              ),
            ],
          ),
        ),
        StatusPill(label: user.detail, color: user.color),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: kRentGoText.withValues(alpha: 0.62),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
}

class _ZoneData {
  const _ZoneData(this.name, this.value, this.color, this.label);

  final String name;
  final double value;
  final Color color;
  final String label;
}

class _ActivityData {
  const _ActivityData(this.title, this.subtitle, this.icon, this.color);

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _UserData {
  const _UserData(this.name, this.status, this.detail, this.color);

  final String name;
  final String status;
  final String detail;
  final Color color;
}
