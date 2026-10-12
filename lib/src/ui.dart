import 'package:flutter/material.dart';

import 'models.dart';

const kRentGoPrimary = Color(0xFF0F766E);
const kRentGoAccent = Color(0xFFF59E0B);
const kRentGoBackground = Color(0xFFF4F1EA);
const kRentGoText = Color(0xFF102A43);

String formatMoney(double? value) {
  final amount = value ?? 0;
  return '${amount.toStringAsFixed(3)} TND';
}

String formatMinutes(int? minutes) {
  if (minutes == null) return '--';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

String formatElapsedRideTime(Duration duration) {
  final safeDuration = duration.isNegative ? Duration.zero : duration;
  final hours = safeDuration.inHours;
  final minutes = safeDuration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = safeDuration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final milliseconds = safeDuration.inMilliseconds.remainder(1000).toString().padLeft(3, '0');

  if (hours > 0) {
    return '$hours:$minutes:$seconds.$milliseconds';
  }

  return '$minutes:$seconds.$milliseconds';
}

double? calculateRideFare({
  required Duration elapsed,
  required double? pricePerMinute,
}) {
  if (pricePerMinute == null) return null;
  final elapsedMillis = elapsed.isNegative ? 0 : elapsed.inMilliseconds;
  return elapsedMillis / Duration.millisecondsPerMinute * pricePerMinute;
}

String formatDateTime(DateTime? value) {
  if (value == null) return '--';
  final date = value.toLocal();
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} · $hour:$minute';
}

Color statusColor(String status) {
  switch (status) {
    case 'available':
      return const Color(0xFF0F766E);
    case 'booked':
      return const Color(0xFFEA580C);
    case 'in_use':
      return const Color(0xFFF59E0B);
    case 'maintenance':
      return const Color(0xFFDC2626);
    case 'offline':
      return const Color(0xFF64748B);
    case 'ongoing':
      return const Color(0xFF0F766E);
    case 'completed':
      return const Color(0xFF2563EB);
    case 'cancelled':
      return const Color(0xFF7C3AED);
    default:
      return const Color(0xFF475569);
  }
}

String statusLabel(String status) {
  switch (status) {
    case 'available':
      return 'Available';
    case 'booked':
      return 'Booked';
    case 'in_use':
      return 'In use';
    case 'maintenance':
      return 'Maintenance';
    case 'offline':
      return 'Offline';
    case 'ongoing':
      return 'Ongoing';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status;
  }
}

class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kRentGoText.withValues(alpha: 0.65)),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onColor = color == Colors.white ? Colors.white : kRentGoText;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 18),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: onColor),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onColor.withValues(alpha: 0.78)),
            ),
          ],
        ),
      ),
    );
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
    this.isBusy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: isBusy ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: kRentGoPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isBusy
            ? const SizedBox(
                key: ValueKey('busy'),
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Row(
                key: const ValueKey('idle'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 10),
                  ],
                  Text(label),
                ],
              ),
      ),
    );

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixPressed,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixPressed;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffixIcon == null
            ? null
            : IconButton(
                onPressed: onSuffixPressed,
                icon: Icon(suffixIcon),
              ),
      ),
    );
  }
}

class AppHeroFrame extends StatelessWidget {
  const AppHeroFrame({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: kRentGoPrimary.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class VehicleMiniCard extends StatelessWidget {
  const VehicleMiniCard({
    super.key,
    required this.vehicle,
    required this.onTap,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(vehicle.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AppPanel(
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
                      vehicle.isBike ? Icons.pedal_bike_rounded : Icons.electric_scooter_rounded,
                      color: color,
                    ),
                  ),
                  const Spacer(),
                  StatusPill(label: statusLabel(vehicle.status), color: color),
                ],
              ),
              const SizedBox(height: 18),
              Text(vehicle.typeLabel, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '${vehicle.batteryLevel}% battery • ${formatMoney(vehicle.pricePerMinute)}/min',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kRentGoText.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.my_location_rounded, size: 16, color: kRentGoAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${vehicle.latitude.toStringAsFixed(4)}, ${vehicle.longitude.toStringAsFixed(4)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kRentGoText.withValues(alpha: 0.6)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
