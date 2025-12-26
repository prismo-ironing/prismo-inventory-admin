/// Model for pharmacy invoice in inventory admin
class PharmacyInvoice {
  final String id;
  final String orderId;
  final String vendorId;
  final String? pharmacyInvoiceNumber;
  final DateTime? pharmacyInvoiceDate;
  final double? pharmacyInvoiceAmount;
  final String? invoiceImageUrl;
  final String? gcsKey;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PharmacyInvoice({
    required this.id,
    required this.orderId,
    required this.vendorId,
    this.pharmacyInvoiceNumber,
    this.pharmacyInvoiceDate,
    this.pharmacyInvoiceAmount,
    this.invoiceImageUrl,
    this.gcsKey,
    required this.createdAt,
    this.updatedAt,
  });

  factory PharmacyInvoice.fromJson(Map<String, dynamic> json) {
    return PharmacyInvoice(
      id: (json['invoiceId'] ?? json['id'] ?? '').toString(),
      orderId: json['orderId'] ?? '',
      vendorId: json['vendorId'] ?? '',
      pharmacyInvoiceNumber: json['pharmacyInvoiceNumber'],
      pharmacyInvoiceDate: json['pharmacyInvoiceDate'] != null
          ? DateTime.tryParse(json['pharmacyInvoiceDate'])
          : null,
      pharmacyInvoiceAmount: json['pharmacyInvoiceAmount']?.toDouble(),
      invoiceImageUrl: json['invoiceImageUrl'],
      gcsKey: json['gcsKey'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }
}

/// Model for orders that need invoices
class OrderForInvoice {
  final String orderId;
  final String? vendorId;
  final String? vendorName;
  final String? customerName;
  final double totalAmount;
  final String status;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final bool hasInvoice;
  final String? invoiceNumber;
  final String? invoiceImageUrl;
  final DateTime? invoiceUploadedAt;

  OrderForInvoice({
    required this.orderId,
    this.vendorId,
    this.vendorName,
    this.customerName,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.deliveredAt,
    required this.hasInvoice,
    this.invoiceNumber,
    this.invoiceImageUrl,
    this.invoiceUploadedAt,
  });

  factory OrderForInvoice.fromJson(Map<String, dynamic> json) {
    return OrderForInvoice(
      orderId: json['orderId'] ?? json['id'] ?? '',
      vendorId: json['vendorId'],
      vendorName: json['vendorName'],
      customerName: json['customerName'],
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'])
          : null,
      hasInvoice: json['hasInvoice'] ?? false,
      invoiceNumber: json['invoiceNumber'],
    );
  }

  /// Factory for parsing from the optimized endpoint response
  /// which has embedded invoice info
  factory OrderForInvoice.fromOptimizedJson(Map<String, dynamic> json) {
    String? invoiceNum;
    String? invoiceImageUrl;
    DateTime? uploadedAt;
    
    // Parse embedded invoice info if present
    final invoice = json['invoice'] as Map<String, dynamic>?;
    if (invoice != null) {
      invoiceNum = invoice['invoiceNumber'];
      invoiceImageUrl = invoice['invoiceImageUrl'];
      uploadedAt = invoice['uploadedAt'] != null 
          ? DateTime.tryParse(invoice['uploadedAt']) 
          : null;
    }

    return OrderForInvoice(
      orderId: json['orderId'] ?? '',
      vendorId: null, // Not returned by optimized endpoint
      vendorName: null,
      customerName: json['customerName'],
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'])
          : null,
      hasInvoice: json['hasInvoice'] ?? false,
      invoiceNumber: invoiceNum,
      invoiceImageUrl: invoiceImageUrl,
      invoiceUploadedAt: uploadedAt,
    );
  }
}

/// Upload result
class InvoiceUploadResult {
  final bool success;
  final String? invoiceId;
  final String? invoiceImageUrl;
  final String? message;
  final String? error;

  InvoiceUploadResult({
    required this.success,
    this.invoiceId,
    this.invoiceImageUrl,
    this.message,
    this.error,
  });

  factory InvoiceUploadResult.fromJson(Map<String, dynamic> json) {
    return InvoiceUploadResult(
      success: json['success'] ?? false,
      invoiceId: json['invoiceId']?.toString(),
      invoiceImageUrl: json['invoiceImageUrl']?.toString(),
      message: json['message']?.toString(),
      error: json['error']?.toString(),
    );
  }
}

