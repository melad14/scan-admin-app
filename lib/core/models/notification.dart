class TechNotification {
  final String id;
  final String type;
  final String titleAr;
  final String bodyAr;
  final String? orderId;
  final bool isRead;
  final DateTime createdAt;

  TechNotification({
    required this.id,
    required this.type,
    required this.titleAr,
    required this.bodyAr,
    this.orderId,
    required this.isRead,
    required this.createdAt,
  });

  factory TechNotification.fromJson(Map<String, dynamic> json) {
    String? parsedOrderId;
    if (json['orderId'] != null) {
      if (json['orderId'] is Map) {
        parsedOrderId = json['orderId']['_id']?.toString() ?? json['orderId']['id']?.toString();
      } else {
        parsedOrderId = json['orderId'].toString();
      }
    }

    return TechNotification(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? '',
      titleAr: json['titleAr'] ?? json['title'] ?? '',
      bodyAr: json['bodyAr'] ?? json['body'] ?? '',
      orderId: parsedOrderId,
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
