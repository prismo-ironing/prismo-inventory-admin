import 'package:flutter/material.dart';

/// Promotion model matching backend API structure
class Promotion {
  final String id;
  final String vendorId;
  final String promotionName;
  final String promotionType; // DISCOUNT_PERCENTAGE, FLAT_DISCOUNT, etc.
  final double? discountValue;
  final double minOrderAmount;
  final double? maxDiscountAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String applicableOn; // ALL_ITEMS, SPECIFIC_MEDICINES, etc.
  final int? usageLimitPerUser;
  final int? totalUsageLimit;
  final String? promoCode;
  final String? description;
  final String? bannerImageUrl;
  final String? termsConditions;
  final bool isActive;
  final String approvalStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  Promotion({
    required this.id,
    required this.vendorId,
    required this.promotionName,
    required this.promotionType,
    this.discountValue,
    required this.minOrderAmount,
    this.maxDiscountAmount,
    required this.startDate,
    required this.endDate,
    required this.applicableOn,
    this.usageLimitPerUser,
    this.totalUsageLimit,
    this.promoCode,
    this.description,
    this.bannerImageUrl,
    this.termsConditions,
    required this.isActive,
    required this.approvalStatus,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'] ?? '',
      vendorId: json['vendorId'] ?? '',
      promotionName: json['promotionName'] ?? '',
      promotionType: json['promotionType'] ?? '',
      discountValue: json['discountValue'] != null 
          ? (json['discountValue'] is int 
              ? (json['discountValue'] as int).toDouble() 
              : json['discountValue'] as double)
          : null,
      minOrderAmount: (json['minOrderAmount'] ?? 0.0) is int
          ? (json['minOrderAmount'] as int).toDouble()
          : (json['minOrderAmount'] ?? 0.0) as double,
      maxDiscountAmount: json['maxDiscountAmount'] != null
          ? (json['maxDiscountAmount'] is int
              ? (json['maxDiscountAmount'] as int).toDouble()
              : json['maxDiscountAmount'] as double)
          : null,
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      applicableOn: json['applicableOn'] ?? 'ALL_ITEMS',
      usageLimitPerUser: json['usageLimitPerUser'],
      totalUsageLimit: json['totalUsageLimit'],
      promoCode: json['promoCode'],
      description: json['description'],
      bannerImageUrl: json['bannerImageUrl'],
      termsConditions: json['termsConditions'],
      isActive: json['isActive'] ?? true,
      approvalStatus: json['approvalStatus'] ?? 'APPROVED',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      createdBy: json['createdBy'],
    );
  }

  /// Get formatted discount text for display
  String get discountText {
    switch (promotionType) {
      case 'DISCOUNT_PERCENTAGE':
        return '${discountValue?.toStringAsFixed(0) ?? 0}% OFF';
      case 'FLAT_DISCOUNT':
        return '₹${discountValue?.toStringAsFixed(0) ?? 0} OFF';
      case 'FREE_DELIVERY':
        return 'Free Delivery';
      case 'CASHBACK':
        return '₹${discountValue?.toStringAsFixed(0) ?? 0} Cashback';
      case 'BUY_X_GET_Y':
        return 'Buy X Get Y';
      case 'BOGO':
        return 'Buy One Get One';
      default:
        return 'Special Offer';
    }
  }

  /// Check if promotion is currently valid
  bool get isValid {
    if (!isActive || approvalStatus != 'APPROVED') return false;
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  /// Get status text
  String get statusText {
    if (!isActive) return 'Inactive';
    if (approvalStatus != 'APPROVED') return approvalStatus;
    if (!isValid) return 'Expired';
    return 'Active';
  }

  /// Get status color
  Color get statusColor {
    if (!isActive) return Colors.grey;
    if (approvalStatus != 'APPROVED') return Colors.orange;
    if (!isValid) return Colors.red;
    return Colors.green;
  }
}

