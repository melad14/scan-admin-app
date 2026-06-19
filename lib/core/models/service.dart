class MedicalService {
  final String id;
  final String nameAr;
  final String nameEn;
  final String category;
  final double price;
  final String description;

  MedicalService({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.category,
    required this.price,
    this.description = '',
  });

  factory MedicalService.fromJson(Map<String, dynamic> json) {
    return MedicalService(
      id: json['_id'] ?? json['serviceId'] ?? '',
      nameAr: json['nameAr'] ?? '',
      nameEn: json['nameEn'] ?? '',
      category: json['category'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'nameAr': nameAr,
      'nameEn': nameEn,
      'category': category,
      'price': price,
      'description': description,
    };
  }
}
