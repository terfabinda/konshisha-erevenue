class MerchantProfile {
  String firstName;
  String lastName;
  String phone;
  String email;
  String tin; // Tax Identification Number
  String agentId;
  String? shopName;
  String? location;

  MerchantProfile({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.tin,
    required this.agentId,
    this.shopName,
    this.location,
  });

  // Convert to JSON for storage
  Map<String, String> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'email': email,
      'tin': tin,
      'agentId': agentId,
      'shopName': shopName ?? '',
      'location': location ?? '',
    };
  }

  // Convert from JSON
  factory MerchantProfile.fromJson(Map<String, dynamic> json) {
    return MerchantProfile(
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      tin: json['tin'] ?? '',
      agentId: json['agentId'] ?? '',
      shopName: json['shopName'],
      location: json['location'],
    );
  }

  // Get full name
  String get fullName => '$firstName $lastName';
}
