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

  Store({
    required this.id,
    required this.name,
    this.address,
    this.isActive = true,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      isActive: json['isActive'] as bool? ?? true,
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

