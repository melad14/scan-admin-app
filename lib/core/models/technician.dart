class MedicalTechnician {
  final String id;
  final String name;
  final String phone;
  final String? photo;
  final double rating;
  final int totalRatings;
  final int completedOrders;
  final String region;
  final bool isAvailable;

  MedicalTechnician({
    required this.id,
    required this.name,
    required this.phone,
    this.photo,
    required this.rating,
    required this.totalRatings,
    required this.completedOrders,
    required this.region,
    required this.isAvailable,
  });

  factory MedicalTechnician.fromJson(Map<String, dynamic> json) {
    return MedicalTechnician(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      photo: json['photo'],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: json['totalRatings'] as int? ?? 0,
      completedOrders: json['completedOrders'] as int? ?? 0,
      region: json['region'] ?? '',
      isAvailable: json['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'phone': phone,
      'photo': photo,
      'rating': rating,
      'totalRatings': totalRatings,
      'completedOrders': completedOrders,
      'region': region,
      'isAvailable': isAvailable,
    };
  }
}
