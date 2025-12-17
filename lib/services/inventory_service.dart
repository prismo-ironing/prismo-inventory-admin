import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/inventory_item.dart';

class InventoryService {
  static const Duration _timeout = Duration(seconds: 30);

  /// Get all stores
  static Future<List<Store>> getStores() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.storesUrl))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final stores = (data['stores'] as List)
              .map((s) => Store.fromJson(s as Map<String, dynamic>))
              .toList();
          return stores;
        }
      }
      throw Exception('Failed to load stores: ${response.statusCode}');
    } catch (e) {
      print('Error fetching stores: $e');
      rethrow;
    }
  }

  /// Get store inventory
  static Future<Map<String, dynamic>> getStoreInventory(String storeId) async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.storeInventoryUrl(storeId)))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final summary = InventorySummary.fromJson(data['summary'] as Map<String, dynamic>);
          final items = (data['items'] as List)
              .map((i) => StoreInventoryItem.fromJson(i as Map<String, dynamic>))
              .toList();
          return {
            'summary': summary,
            'items': items,
          };
        }
      }
      throw Exception('Failed to load inventory: ${response.statusCode}');
    } catch (e) {
      print('Error fetching inventory: $e');
      rethrow;
    }
  }

  /// Get inventory stats
  static Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.statsUrl))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'totalMedicines': data['totalMedicinesInCatalog'],
            'totalInventory': data['totalInventoryRecords'],
            'totalStores': data['totalStores'],
          };
        }
      }
      throw Exception('Failed to load stats');
    } catch (e) {
      print('Error fetching stats: $e');
      rethrow;
    }
  }

  /// Upload inventory from parsed Excel/CSV data with batching for large files
  /// [onProgress] callback receives (completed, total, currentBatch, totalBatches)
  static Future<UploadResponse> uploadInventory(
    String storeId, 
    List<InventoryItem> items, {
    void Function(int completed, int total, int currentBatch, int totalBatches)? onProgress,
  }) async {
    const int batchSize = 500; // Upload 500 items at a time
    final int totalItems = items.length;
    final int totalBatches = (totalItems / batchSize).ceil();
    
    print('Uploading $totalItems items in $totalBatches batches to store $storeId');
    
    // Aggregate results across batches
    int newMedicinesAdded = 0;
    int existingMedicinesUpdated = 0;
    int inventoryItemsCreated = 0;
    int inventoryItemsUpdated = 0;
    int failedItems = 0;
    List<UploadError> allErrors = [];
    
    for (int batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
      final int start = batchIndex * batchSize;
      final int end = (start + batchSize > totalItems) ? totalItems : start + batchSize;
      final batch = items.sublist(start, end);
      
      print('Uploading batch ${batchIndex + 1}/$totalBatches (items $start-$end)');
      onProgress?.call(start, totalItems, batchIndex + 1, totalBatches);
      
      try {
        final requestBody = json.encode({
          'storeId': storeId,
          'items': batch.map((i) => i.toJson()).toList(),
        });

        final response = await http
            .post(
              Uri.parse(ApiConfig.uploadUrl),
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            )
            .timeout(const Duration(seconds: 120)); // 2 min timeout per batch

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          newMedicinesAdded += (data['newMedicinesAdded'] as int? ?? 0);
          existingMedicinesUpdated += (data['existingMedicinesUpdated'] as int? ?? 0);
          inventoryItemsCreated += (data['inventoryItemsCreated'] as int? ?? 0);
          inventoryItemsUpdated += (data['inventoryItemsUpdated'] as int? ?? 0);
          failedItems += (data['failedItems'] as int? ?? 0);
          if (data['errors'] != null) {
            final errors = (data['errors'] as List)
                .map((e) => UploadError.fromJson(e as Map<String, dynamic>))
                .toList();
            allErrors.addAll(errors);
          }
          print('Batch ${batchIndex + 1} completed successfully');
        } else {
          print('Batch ${batchIndex + 1} failed: ${response.statusCode}');
          failedItems += batch.length;
        }
      } catch (e) {
        print('Error uploading batch ${batchIndex + 1}: $e');
        failedItems += batch.length;
        allErrors.add(UploadError(
          errorMessage: 'Batch ${batchIndex + 1} failed: $e',
        ));
      }
    }
    
    onProgress?.call(totalItems, totalItems, totalBatches, totalBatches);
    
    return UploadResponse(
      success: failedItems == 0,
      message: 'Upload completed. $newMedicinesAdded new, $existingMedicinesUpdated updated, $inventoryItemsCreated created, $inventoryItemsUpdated inventory updated${failedItems > 0 ? ", $failedItems failed" : ""}',
      totalItems: totalItems,
      newMedicinesAdded: newMedicinesAdded,
      existingMedicinesUpdated: existingMedicinesUpdated,
      inventoryItemsCreated: inventoryItemsCreated,
      inventoryItemsUpdated: inventoryItemsUpdated,
      failedItems: failedItems,
      errors: allErrors,
    );
  }

  /// Get low stock alerts
  static Future<List<Map<String, dynamic>>> getAlerts(String storeId) async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.storeAlertsUrl(storeId)))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['alerts'] ?? []);
        }
      }
      throw Exception('Failed to load alerts');
    } catch (e) {
      print('Error fetching alerts: $e');
      rethrow;
    }
  }

  /// Delete inventory item
  static Future<bool> deleteInventoryItem(String storeId, String medicineId) async {
    try {
      final response = await http
          .delete(Uri.parse('${ApiConfig.storeInventoryUrl(storeId)}/$medicineId'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error deleting item: $e');
      return false;
    }
  }
}

