/// Model for promotion items parsed from Excel
class PromotionItem {
  final String? promotionName;
  final String? promotionType; // DISCOUNT_PERCENTAGE, FLAT_DISCOUNT, etc.
  final double? discountValue;
  final double? minOrderAmount;
  final double? maxDiscountAmount;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? applicableOn; // ALL_ITEMS, SPECIFIC_MEDICINES, SPECIFIC_CATEGORIES, etc.
  final int? usageLimitPerUser;
  final int? totalUsageLimit;
  final String? promoCode;
  final String? description;
  final String? bannerImageUrl;
  final String? termsConditions;
  final bool? isActive;
  final String? createdBy;
  final String? medicineIds; // Comma-separated or semicolon-separated
  final String? categories; // Comma-separated or semicolon-separated

  PromotionItem({
    this.promotionName,
    this.promotionType,
    this.discountValue,
    this.minOrderAmount,
    this.maxDiscountAmount,
    this.startDate,
    this.endDate,
    this.applicableOn,
    this.usageLimitPerUser,
    this.totalUsageLimit,
    this.promoCode,
    this.description,
    this.bannerImageUrl,
    this.termsConditions,
    this.isActive,
    this.createdBy,
    this.medicineIds,
    this.categories,
  });

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    // Parse medicine IDs and categories from comma/semicolon-separated strings
    List<String>? parsedMedicineIds;
    if (medicineIds != null && medicineIds!.isNotEmpty) {
      parsedMedicineIds = medicineIds!
          .split(RegExp(r'[,;]'))
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList();
      if (parsedMedicineIds.isEmpty) parsedMedicineIds = null;
    }

    List<String>? parsedCategories;
    if (categories != null && categories!.isNotEmpty) {
      parsedCategories = categories!
          .split(RegExp(r'[,;]'))
          .map((cat) => cat.trim())
          .where((cat) => cat.isNotEmpty)
          .toList();
      if (parsedCategories.isEmpty) parsedCategories = null;
    }

    return {
      'promotionName': promotionName,
      'promotionType': promotionType,
      'discountValue': discountValue,
      'minOrderAmount': minOrderAmount ?? 0.0,
      'maxDiscountAmount': maxDiscountAmount,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'applicableOn': applicableOn ?? 'ALL_ITEMS',
      'usageLimitPerUser': usageLimitPerUser,
      'totalUsageLimit': totalUsageLimit,
      'promoCode': promoCode,
      'description': description,
      'bannerImageUrl': bannerImageUrl,
      'termsConditions': termsConditions,
      'isActive': isActive ?? true,
      'createdBy': createdBy,
      'medicineIds': parsedMedicineIds,
      'categories': parsedCategories,
    };
  }
}

/// Response from promotion upload
class PromotionUploadResponse {
  final bool success;
  final String message;
  final int totalItems;
  final int successfulPromotions;
  final int failedPromotions;
  final List<PromotionUploadError> errors;

  PromotionUploadResponse({
    required this.success,
    required this.message,
    required this.totalItems,
    required this.successfulPromotions,
    required this.failedPromotions,
    required this.errors,
  });

  factory PromotionUploadResponse.fromJson(Map<String, dynamic> json) {
    return PromotionUploadResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      totalItems: json['totalItems'] ?? 0,
      successfulPromotions: json['successfulPromotions'] ?? 0,
      failedPromotions: json['failedPromotions'] ?? 0,
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => PromotionUploadError.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Error from promotion upload
class PromotionUploadError {
  final String? promotionName;
  final String? errorMessage;

  PromotionUploadError({
    this.promotionName,
    this.errorMessage,
  });

  factory PromotionUploadError.fromJson(Map<String, dynamic> json) {
    return PromotionUploadError(
      promotionName: json['promotionName'],
      errorMessage: json['errorMessage'],
    );
  }
}

