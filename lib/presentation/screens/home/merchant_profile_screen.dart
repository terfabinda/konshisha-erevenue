import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/merchant_profile.dart';
import '../../../data/models/merchant_profile_service.dart';

class MerchantProfileScreen extends StatefulWidget {
  const MerchantProfileScreen({super.key});

  @override
  State<MerchantProfileScreen> createState() => _MerchantProfileScreenState();
}

class _MerchantProfileScreenState extends State<MerchantProfileScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _tinController;
  late TextEditingController _agentIdController;
  late TextEditingController _shopNameController;
  late TextEditingController _locationController;

  bool _isLoading = true;
  bool _isEditing = false;
  MerchantProfile? _profile;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadProfile();
  }

  void _initializeControllers() {
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _tinController = TextEditingController();
    _agentIdController = TextEditingController();
    _shopNameController = TextEditingController();
    _locationController = TextEditingController();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await MerchantProfileService.loadProfile();
      setState(() {
        _profile = profile;
        if (profile != null) {
          _firstNameController.text = profile.firstName;
          _lastNameController.text = profile.lastName;
          _phoneController.text = profile.phone;
          _emailController.text = profile.email;
          _tinController.text = profile.tin;
          _agentIdController.text = profile.agentId;
          _shopNameController.text = profile.shopName ?? '';
          _locationController.text = profile.location ?? '';
        } else {
          // Set default values if no profile exists
          _agentIdController.text = AppStrings.defaultAgentId;
        }
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _tinController.text.isEmpty ||
        _agentIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    try {
      final profile = MerchantProfile(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        tin: _tinController.text,
        agentId: _agentIdController.text,
        shopName: _shopNameController.text.isEmpty
            ? null
            : _shopNameController.text,
        location: _locationController.text.isEmpty
            ? null
            : _locationController.text,
      );

      await MerchantProfileService.saveProfile(profile);

      setState(() {
        _profile = profile;
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _tinController.dispose();
    _agentIdController.dispose();
    _shopNameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Merchant Profile"),
        backgroundColor: Colors.green.shade800,
        actions: [
          if (!_isEditing && _profile != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_profile == null && !_isEditing)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60),
                          const Icon(
                            Icons.person_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text('No profile found'),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => setState(() => _isEditing = true),
                            icon: const Icon(Icons.add),
                            label: const Text('Create Profile'),
                          ),
                          const SizedBox(height: 60),
                        ],
                      ),
                    )
                  else if (_isEditing)
                    _buildProfileForm()
                  else
                    _buildProfileView(),
                  if (_isEditing)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _loadProfile();
                                setState(() => _isEditing = false);
                              },
                              icon: const Icon(Icons.close),
                              label: const Text("Cancel"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saveProfile,
                              icon: const Icon(Icons.save),
                              label: const Text("Save"),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                _profile!.fullName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _profile!.agentId,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        _buildInfoCard("Personal Information", [
          _infoRow("First Name", _profile!.firstName),
          _infoRow("Last Name", _profile!.lastName),
          _infoRow("Email", _profile!.email),
          _infoRow("Phone", _profile!.phone),
        ]),
        const SizedBox(height: 16),
        _buildInfoCard("Tax & Identification", [
          _infoRow("TIN (Tax ID)", _profile!.tin),
          _infoRow("Agent ID", _profile!.agentId),
        ]),
        if (_profile!.shopName != null && _profile!.shopName!.isNotEmpty)
          Column(
            children: [
              const SizedBox(height: 16),
              _buildInfoCard("Business Information", [
                _infoRow("Shop Name", _profile!.shopName!),
                if (_profile!.location != null &&
                    _profile!.location!.isNotEmpty)
                  _infoRow("Location", _profile!.location!),
              ]),
            ],
          ),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Personal Information",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildTextField("First Name *", _firstNameController),
        const SizedBox(height: 12),
        _buildTextField("Last Name *", _lastNameController),
        const SizedBox(height: 12),
        _buildTextField(
          "Email *",
          _emailController,
          TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _buildTextField("Phone *", _phoneController, TextInputType.phone),
        const SizedBox(height: 24),
        const Text(
          "Tax & Identification",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildTextField("TIN (Tax Identification Number) *", _tinController),
        const SizedBox(height: 12),
        _buildTextField("Agent ID *", _agentIdController),
        const SizedBox(height: 24),
        const Text(
          "Business Information (Optional)",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildTextField("Shop/Business Name", _shopNameController),
        const SizedBox(height: 12),
        _buildTextField("Location/Address", _locationController),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, [
    TextInputType keyboardType = TextInputType.text,
  ]) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: _isEditing,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
      ),
    );
  }
}
