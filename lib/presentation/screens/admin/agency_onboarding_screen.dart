import 'package:flutter/material.dart';
import '../../../core/models/agency.dart';
import '../../../core/services/agency_service.dart';
import '../../../core/services/auth_service.dart';
import '../../widgets/agency_form.dart';
import '../../widgets/category_config_widget.dart';

class AgencyOnboardingScreen extends StatefulWidget {
  const AgencyOnboardingScreen({super.key});

  @override
  State<AgencyOnboardingScreen> createState() => _AgencyOnboardingScreenState();
}

class _AgencyOnboardingScreenState extends State<AgencyOnboardingScreen> {
  int _step = 0;
  Agency? _draftAgency;
  Map<String, dynamic>? _categorySettings;
  bool _isLoading = false;

  void _nextStep() {
    if (_step == 0 && _draftAgency == null) return;
    setState(() => _step++);
  }

  void _prevStep() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _submitAgency() async {
    if (_draftAgency == null) return;
    setState(() => _isLoading = true);

    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) throw Exception('Not logged in');

      final agency = _draftAgency!.copyWith(
        onboardedBy: user.uid,
        customSettings: _categorySettings,
      );

      await AgencyService.createAgency(agency);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agency created successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['Agency Details', 'Revenue Categories', 'Review'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboard Agency'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                ...steps.asMap().entries.map((entry) {
                  final isCurrent = entry.key == _step;
                  final isDone = entry.key < _step;
                  return Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDone
                                ? Colors.green
                                : isCurrent
                                    ? Colors.blue
                                    : Colors.grey.shade300,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : Text(
                                    '${entry.key + 1}',
                                    style: TextStyle(
                                      color: isCurrent ? Colors.white : Colors.grey.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                        if (entry.key < steps.length - 1)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: entry.key < _step ? Colors.green : Colors.grey.shade300,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Details', style: TextStyle(fontSize: 12)),
                Text('Categories', style: TextStyle(fontSize: 12)),
                Text('Review', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _step == 0
                ? AgencyForm(
                    agency: _draftAgency,
                    isLoading: false,
                    onSubmit: (agency) {
                      setState(() => _draftAgency = agency);
                      _nextStep();
                    },
                  )
                : _step == 1
                    ? Column(
                        children: [
                          Expanded(
                            child: CategoryConfigWidget(
                              currentSettings: _draftAgency?.customSettings,
                              onChange: (settings) => _categorySettings = settings,
                            ),
                          ),
                        ],
                      )
                    : _buildReview(),
          ),
          if (_step > 0)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _isLoading ? null : _prevStep,
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitAgency,
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Create Agency'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReview() {
    final a = _draftAgency!;
    final enabledCount = (_categorySettings?['categories'] as Map?)?.entries
            .where((e) => (e.value as Map)['enabled'] == true)
            .length ??
        0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _reviewTile('Agency Name', a.name),
        _reviewTile('Code', a.code),
        if (a.address != null && a.address!.isNotEmpty) _reviewTile('Address', a.address!),
        if (a.phone != null && a.phone!.isNotEmpty) _reviewTile('Phone', a.phone!),
        if (a.email != null && a.email!.isNotEmpty) _reviewTile('Email', a.email!),
        if (a.tin != null && a.tin!.isNotEmpty) _reviewTile('TIN', a.tin!),
        const Divider(),
        _reviewTile('Contact Name', a.adminName),
        _reviewTile('Contact Phone', a.adminPhone),
        const Divider(),
        _reviewTile('Receipt Prefix', a.receiptPrefix.toString()),
        _reviewTile('Categories Enabled', '$enabledCount of 30'),
      ],
    );
  }

  Widget _reviewTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
