import 'package:flutter/material.dart';

import '../models.dart';
import '../ui.dart';

class ReportIssuePage extends StatefulWidget {
  const ReportIssuePage({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  State<ReportIssuePage> createState() => _ReportIssuePageState();
}

class _ReportIssuePageState extends State<ReportIssuePage> {
  static const _categories = [
    'Freins',
    'Batterie',
    'Pneus',
    'Guidon / Direction',
    'Eclairage',
    'Autre',
  ];

  String? _category; // null = aucune catégorie sélectionnée par défaut
  final _detailsController = TextEditingController();
  bool _hasPhoto = false;
  bool _submitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    // Pas encore de package image_picker dans pubspec.yaml.
    // Pour l'instant on simule juste l'ajout d'une photo.
    setState(() => _hasPhoto = true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo ajoutee (simulation).')),
    );
  }

  Future<void> _submit() async {
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis une categorie avant d\'envoyer.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      // TODO: remplacer par un vrai appel, ex:
      // final scope = AppScope.of(context);
      // await scope.api.reportIssue(
      //   token: scope.session.token!,
      //   vehicleId: widget.vehicle.id,
      //   category: _category!,
      //   details: _detailsController.text,
      // );
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Probleme signale, merci.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler un probleme')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Vehicule ${widget.vehicle.qrCode ?? widget.vehicle.id}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: kRentGoText.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Categorie',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: kRentGoText.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _category,
            hint: const Text('Selectionner une categorie'),
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            items: _categories
                .map(
                  (c) => DropdownMenuItem<String>(value: c, child: Text(c)),
                )
                .toList(),
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: Icon(
              _hasPhoto ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
              color: _hasPhoto ? const Color(0xFF16BFB8) : kRentGoText,
            ),
            label: Text(_hasPhoto ? 'Photo ajoutee' : 'Photo'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.centerLeft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _detailsController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Details (optionnel)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 28),
          AppButton(
            label: 'Envoyer',
            icon: Icons.send_rounded,
            expanded: true,
            isBusy: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}