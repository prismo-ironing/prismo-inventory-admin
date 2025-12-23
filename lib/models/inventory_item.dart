import 'dart:convert';

class InventoryItem {
  final int? serialNo;
  final String productName;
  final String? composition;
  final String? company;
  final String? category;
  final String? packSize;
  final int inventoryQty;
  final String? inventoryType;
  final double? mrp;
  final double sellingPrice;
  final String? usedIn;
  final String? precautions;
  final String? imageUrl1;
  final String? imageUrl2;
  final String? prescriptionInfo;

  InventoryItem({
    this.serialNo,
    required this.productName,
    this.composition,
    this.company,
    this.category,
    this.packSize,
    required this.inventoryQty,
    this.inventoryType,
    this.mrp,
    required this.sellingPrice,
    this.usedIn,
    this.precautions,
    this.imageUrl1,
    this.imageUrl2,
    this.prescriptionInfo,
  });

  Map<String, dynamic> toJson() {
    return {
      'serialNo': serialNo,
      'productName': productName,
      'composition': composition,
      'company': company,
      'category': category,
      'packSize': packSize,
      'inventoryQty': inventoryQty,
      'inventoryType': inventoryType,
      'mrp': mrp,
      'sellingPrice': sellingPrice,
      'usedIn': usedIn,
      'precautions': precautions,
      'imageUrl1': imageUrl1,
      'imageUrl2': imageUrl2,
      'prescriptionInfo': prescriptionInfo,
    };
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      serialNo: json['serialNo'] as int?,
      productName: json['productName'] as String,
      composition: json['composition'] as String?,
      company: json['company'] as String?,
      category: json['category'] as String?,
      packSize: json['packSize'] as String?,
      inventoryQty: json['inventoryQty'] as int? ?? 0,
      inventoryType: json['inventoryType'] as String?,
      mrp: (json['mrp'] as num?)?.toDouble(),
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      usedIn: json['usedIn'] as String?,
      precautions: json['precautions'] as String?,
      imageUrl1: json['imageUrl1'] as String?,
      imageUrl2: json['imageUrl2'] as String?,
      prescriptionInfo: json['prescriptionInfo'] as String?,
    );
  }
}

class Store {
  final String id;
  final String name;
  final String? address;
  final bool isActive;
  final int totalMedicines;
  final int activeMedicines;
  final int expiredMedicines;
  final int lowStock;
  final int outOfStock;

  Store({
    required this.id,
    required this.name,
    this.address,
    this.isActive = true,
    this.totalMedicines = 0,
    this.activeMedicines = 0,
    this.expiredMedicines = 0,
    this.lowStock = 0,
    this.outOfStock = 0,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      totalMedicines: json['totalMedicines'] as int? ?? 0,
      activeMedicines: json['activeMedicines'] as int? ?? 0,
      expiredMedicines: json['expiredMedicines'] as int? ?? 0,
      lowStock: json['lowStock'] as int? ?? 0,
      outOfStock: json['outOfStock'] as int? ?? 0,
    );
  }
}

class StoreInventoryItem {
  final int inventoryId;
  final String medicineId;
  final String brandName;
  final String? genericName;
  final String? composition;
  final String? manufacturer;
  final String? category;
  final String? form;
  final String? packSize;
  final double? mrp;
  final double sellingPrice;
  final int stockQuantity;
  final String availabilityStatus;
  final bool isAvailable;
  final String? lastUpdatedAt;
  final String? batchNumber;
  final String? expiryDate;

  StoreInventoryItem({
    required this.inventoryId,
    required this.medicineId,
    required this.brandName,
    this.genericName,
    this.composition,
    this.manufacturer,
    this.category,
    this.form,
    this.packSize,
    this.mrp,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.availabilityStatus,
    required this.isAvailable,
    this.lastUpdatedAt,
    this.batchNumber,
    this.expiryDate,
  });

  factory StoreInventoryItem.fromJson(Map<String, dynamic> json) {
    return StoreInventoryItem(
      inventoryId: json['inventoryId'] as int,
      medicineId: json['medicineId'] as String,
      brandName: json['brandName'] as String,
      genericName: json['genericName'] as String?,
      composition: json['composition'] as String?,
      manufacturer: json['manufacturer'] as String?,
      category: json['category'] as String?,
      form: json['form'] as String?,
      packSize: json['packSize'] as String?,
      mrp: (json['mrp'] as num?)?.toDouble(),
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: json['stockQuantity'] as int? ?? 0,
      availabilityStatus: json['availabilityStatus'] as String? ?? 'UNKNOWN',
      isAvailable: json['isAvailable'] as bool? ?? false,
      lastUpdatedAt: json['lastUpdatedAt'] as String?,
      batchNumber: json['batchNumber'] as String?,
      expiryDate: json['expiryDate'] as String?,
    );
  }
}

class InventorySummary {
  final int totalItems;
  final int inStock;
  final int lowStock;
  final int outOfStock;
  final double totalInventoryValue;

  InventorySummary({
    required this.totalItems,
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
    required this.totalInventoryValue,
  });

  factory InventorySummary.fromJson(Map<String, dynamic> json) {
    return InventorySummary(
      totalItems: json['totalItems'] as int? ?? 0,
      inStock: json['inStock'] as int? ?? 0,
      lowStock: json['lowStock'] as int? ?? 0,
      outOfStock: json['outOfStock'] as int? ?? 0,
      totalInventoryValue: (json['totalInventoryValue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class UploadResponse {
  final bool success;
  final String message;
  final int totalItems;
  final int newMedicinesAdded;
  final int existingMedicinesUpdated;
  final int inventoryItemsCreated;
  final int inventoryItemsUpdated;
  final int failedItems;
  final List<UploadError> errors;

  UploadResponse({
    required this.success,
    required this.message,
    required this.totalItems,
    required this.newMedicinesAdded,
    required this.existingMedicinesUpdated,
    required this.inventoryItemsCreated,
    required this.inventoryItemsUpdated,
    required this.failedItems,
    required this.errors,
  });

  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      totalItems: json['totalItems'] as int? ?? 0,
      newMedicinesAdded: json['newMedicinesAdded'] as int? ?? 0,
      existingMedicinesUpdated: json['existingMedicinesUpdated'] as int? ?? 0,
      inventoryItemsCreated: json['inventoryItemsCreated'] as int? ?? 0,
      inventoryItemsUpdated: json['inventoryItemsUpdated'] as int? ?? 0,
      failedItems: json['failedItems'] as int? ?? 0,
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => UploadError.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class UploadError {
  final int? serialNo;
  final String? productName;
  final String errorMessage;

  UploadError({
    this.serialNo,
    this.productName,
    required this.errorMessage,
  });

  factory UploadError.fromJson(Map<String, dynamic> json) {
    return UploadError(
      serialNo: json['serialNo'] as int?,
      productName: json['productName'] as String?,
      errorMessage: json['errorMessage'] as String? ?? 'Unknown error',
    );
  }
}

class PaginationInfo {
  final int page;
  final int size;
  final int totalItems;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;

  PaginationInfo({
    required this.page,
    required this.size,
    required this.totalItems,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 50,
      totalItems: json['totalItems'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 1,
      hasNext: json['hasNext'] as bool? ?? false,
      hasPrevious: json['hasPrevious'] as bool? ?? false,
    );
  }
}

// =====================================================
// DEDUCTION MODELS
// =====================================================

/// Item to deduct from inventory (used in bulk deduction)
class DeductionItem {
  final int? serialNo;
  final String? medicineId;
  final String? productName;
  final int quantityToDeduct;
  final String? reason;
  final String? batchNumber;

  DeductionItem({
    this.serialNo,
    this.medicineId,
    this.productName,
    required this.quantityToDeduct,
    this.reason,
    this.batchNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      if (serialNo != null) 'serialNo': serialNo,
      if (medicineId != null) 'medicineId': medicineId,
      if (productName != null) 'productName': productName,
      'quantityToDeduct': quantityToDeduct,
      if (reason != null) 'reason': reason,
      if (batchNumber != null) 'batchNumber': batchNumber,
    };
  }
}

/// Response from bulk deduction API
class DeductionResponse {
  final bool success;
  final String message;
  final int totalItems;
  final int successfulDeductions;
  final int itemsSetToZero;
  final int itemsRemoved;
  final int failedItems;
  final int skippedItems;
  final List<DeductionResult> results;
  final List<DeductionError> errors;

  DeductionResponse({
    required this.success,
    required this.message,
    required this.totalItems,
    required this.successfulDeductions,
    required this.itemsSetToZero,
    required this.itemsRemoved,
    required this.failedItems,
    required this.skippedItems,
    required this.results,
    required this.errors,
  });

  factory DeductionResponse.fromJson(Map<String, dynamic> json) {
    return DeductionResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      totalItems: json['totalItems'] as int? ?? 0,
      successfulDeductions: json['successfulDeductions'] as int? ?? 0,
      itemsSetToZero: json['itemsSetToZero'] as int? ?? 0,
      itemsRemoved: json['itemsRemoved'] as int? ?? 0,
      failedItems: json['failedItems'] as int? ?? 0,
      skippedItems: json['skippedItems'] as int? ?? 0,
      results: (json['results'] as List<dynamic>?)
              ?.map((e) => DeductionResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => DeductionError.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Result of a successful deduction
class DeductionResult {
  final int? serialNo;
  final String medicineId;
  final String? productName;
  final int previousStock;
  final int quantityDeducted;
  final int newStock;
  final String status; // SUCCESS, ZERO_STOCK, REMOVED

  DeductionResult({
    this.serialNo,
    required this.medicineId,
    this.productName,
    required this.previousStock,
    required this.quantityDeducted,
    required this.newStock,
    required this.status,
  });

  factory DeductionResult.fromJson(Map<String, dynamic> json) {
    return DeductionResult(
      serialNo: json['serialNo'] as int?,
      medicineId: json['medicineId'] as String? ?? '',
      productName: json['productName'] as String?,
      previousStock: json['previousStock'] as int? ?? 0,
      quantityDeducted: json['quantityDeducted'] as int? ?? 0,
      newStock: json['newStock'] as int? ?? 0,
      status: json['status'] as String? ?? 'UNKNOWN',
    );
  }
}

/// Error from a failed deduction
class DeductionError {
  final int? serialNo;
  final String? medicineId;
  final String? productName;
  final String errorMessage;
  final String? errorCode; // NOT_FOUND, INSUFFICIENT_STOCK, INVALID_QUANTITY, etc.
  final int? requestedDeduction;
  final int? availableStock;

  DeductionError({
    this.serialNo,
    this.medicineId,
    this.productName,
    required this.errorMessage,
    this.errorCode,
    this.requestedDeduction,
    this.availableStock,
  });

  factory DeductionError.fromJson(Map<String, dynamic> json) {
    return DeductionError(
      serialNo: json['serialNo'] as int?,
      medicineId: json['medicineId'] as String?,
      productName: json['productName'] as String?,
      errorMessage: json['errorMessage'] as String? ?? 'Unknown error',
      errorCode: json['errorCode'] as String?,
      requestedDeduction: json['requestedDeduction'] as int?,
      availableStock: json['availableStock'] as int?,
    );
  }
}

// =====================================================
// BULK DELETE MODELS
// =====================================================

/// Item to delete from inventory
class DeleteItem {
  final String? productName;
  final String? medicineId;

  DeleteItem({
    this.productName,
    this.medicineId,
  });

  Map<String, dynamic> toJson() {
    return {
      if (productName != null) 'productName': productName,
      if (medicineId != null) 'medicineId': medicineId,
    };
  }
}

/// Response from bulk delete operation
class BulkDeleteResponse {
  final bool success;
  final String message;
  final int totalItems;
  final int successfulDeletes;
  final int notFoundItems;
  final int failedDeletes;
  final List<BulkDeleteError> errors;

  BulkDeleteResponse({
    required this.success,
    required this.message,
    required this.totalItems,
    required this.successfulDeletes,
    required this.notFoundItems,
    required this.failedDeletes,
    required this.errors,
  });

  factory BulkDeleteResponse.fromJson(Map<String, dynamic> json) {
    return BulkDeleteResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      totalItems: json['totalItems'] as int? ?? 0,
      successfulDeletes: json['successfulDeletes'] as int? ?? 0,
      notFoundItems: json['notFoundItems'] as int? ?? 0,
      failedDeletes: json['failedDeletes'] as int? ?? 0,
      errors: (json['errors'] as List?)
              ?.map((e) => BulkDeleteError.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Error from bulk delete operation
class BulkDeleteError {
  final String? productName;
  final String? medicineId;
  final String error;

  BulkDeleteError({
    this.productName,
    this.medicineId,
    required this.error,
  });

  factory BulkDeleteError.fromJson(Map<String, dynamic> json) {
    return BulkDeleteError(
      productName: json['productName'] as String?,
      medicineId: json['medicineId'] as String?,
      error: json['error'] as String? ?? 'Unknown error',
    );
  }
}

