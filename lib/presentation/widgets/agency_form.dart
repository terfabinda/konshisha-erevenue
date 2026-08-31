import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/agency.dart';

class AgencyForm extends StatefulWidget {
  final Agency? agency;
  final Function(Agency) onSubmit;
  final bool isLoading;

  const AgencyForm({
    super.key,
    this.agency,
    required this.onSubmit,
    this.isLoading = false,
  });

  @override
  State<AgencyForm> createState() => _AgencyFormState();
}

class _AgencyFormState extends State<AgencyForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _tinController;
  late final TextEditingController _adminNameController;
  late final TextEditingController _adminPhoneController;
  late final TextEditingController _receiptPrefixController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.agency?.name ?? '');
    _codeController = TextEditingController(text: widget.agency?.code ?? '');
    _addressController = TextEditingController(text: widget.agency?.address ?? '');
    _phoneController = TextEditingController(text: widget.agency?.phone ?? '');
    _emailController = TextEditingController(text: widget.agency?.email ?? '');
    _tinController = TextEditingController(text: widget.agency?.tin ?? '');
    _adminNameController = TextEditingController(text: widget.agency?.adminName ?? '');
    _adminPhoneController = TextEditingController(text: widget.agency?.adminPhone ?? '');
    _receiptPrefixController = TextEditingController(
      text: (widget.agency?.receiptPrefix ?? 1000).toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _tinController.dispose();
    _adminNameController.dispose();
    _adminPhoneController.dispose();
    _receiptPrefixController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final agency = Agency(
      id: widget.agency?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      code: _codeController.text.trim().toUpperCase(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      tin: _tinController.text.trim(),
      adminName: _adminNameController.text.trim(),
      adminPhone: _adminPhoneController.text.trim(),
      receiptPrefix: int.tryParse(_receiptPrefixController.text) ?? 1000,
      onboardedBy: widget.agency?.onboardedBy ?? '',
    );

    widget.onSubmit(agency);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Agency Name',
              hintText: AppStrings.agencyHint,
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'Short Code',
              hintText: AppStrings.agencyCodeHint,
              prefixIcon: Icon(Icons.tag),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Code is required';
              if (v.trim().length > 5) return 'Code must be 1-5 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Phone is required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v != null && v.isNotEmpty && !v.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tinController,
            decoration: const InputDecoration(
              labelText: 'Tax ID (TIN)',
              prefixIcon: Icon(Icons.numbers),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Contact Person', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _adminNameController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _adminPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact Phone',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Phone is required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _receiptPrefixController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Receipt Prefix (numeric)',
              prefixIcon: Icon(Icons.receipt_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (int.tryParse(v.trim()) == null) return 'Must be a number';
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : _submit,
              child: widget.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Agency', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
