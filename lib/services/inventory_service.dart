import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/inventory_item.dart';

class InventoryService {
  static const Duration _timeout = Duration(seconds: 10); // Reduced timeout for faster failure
  static const Duration _inventoryTimeout = Duration(seconds: 30); // Longer timeout for inventory

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

  /// Get stores by specific IDs (optimized - only fetches what you need)
  static Future<List<Store>> getStoresByIds(List<String> storeIds) async {
    if (storeIds.isEmpty) {
      return [];
    }
    
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.storesByIdsUrl(storeIds)))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final stores = (data['stores'] as List)
              .map((s) => Store.fromJson(s as Map<String, dynamic>))
              .toList();
          print('Fetched ${stores.length} stores by IDs');
          return stores;
        }
      }
      throw Exception('Failed to load stores: ${response.statusCode}');
    } catch (e) {
      print('Error fetching stores by IDs: $e');
      rethrow;
    }
  }

  /// Get store inventory with pagination and filtering
  /// Returns items for a specific page, plus summary (calculated from all items)
  /// [status] can be: 'all', 'in_stock', 'low_stock', 'out_of_stock', 'active'
  static Future<Map<String, dynamic>> getStoreInventory(
    String storeId, {
    int page = 0,
    int size = 50,
    String status = 'all',
    String? search,
  }) async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.storeInventoryUrl(
            storeId, 
            page: page, 
            size: size, 
            status: status,
            search: search,
          )))
          .timeout(_inventoryTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final summary = InventorySummary.fromJson(data['summary'] as Map<String, dynamic>);
          final items = (data['items'] as List)
              .map((i) => StoreInventoryItem.fromJson(i as Map<String, dynamic>))
              .toList();
          
          // Parse pagination info if available
          final paginationData = data['pagination'] as Map<String, dynamic>?;
          
          return {
            'summary': summary,
            'items': items,
            'pagination': paginationData != null ? PaginationInfo.fromJson(paginationData) : null,
          };
        }
      }
      throw Exception('Failed to load inventory: ${response.statusCode}');
    } catch (e) {
      print('Error fetching inventory: $e');
      rethrow;
    }
  }

  /// Get all store inventory items (fetches all pages)
  /// Use this only when you need ALL items (e.g., for stats calculation)
  static Future<Map<String, dynamic>> getAllStoreInventory(String storeId) async {
    List<StoreInventoryItem> allItems = [];
    InventorySummary? summary;
    int page = 0;
    const int size = 100; // Larger page size for bulk fetching
    bool hasMore = true;

    while (hasMore) {
      final result = await getStoreInventory(storeId, page: page, size: size);
      summary = result['summary'] as InventorySummary;
      final items = result['items'] as List<StoreInventoryItem>;
      final pagination = result['pagination'] as PaginationInfo?;
      
      allItems.addAll(items);
      
      hasMore = pagination?.hasNext ?? false;
      page++;
      
      // Safety: don't fetch more than 50 pages (5000 items)
      if (page > 50) break;
    }

    return {
      'summary': summary,
      'items': allItems,
    };
  }

  /// Get inventory stats (global - for admins only)
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

  /// Get inventory stats for specific stores (for non-admin managers)
  /// Uses summary data from server (calculated from ALL items, not just first page)
  static Future<Map<String, dynamic>> getStatsForStores(List<String> vendorIds) async {
    if (vendorIds.isEmpty) {
      return {
        'totalMedicines': 0,
        'totalInventory': 0,
        'totalStores': 0,
      };
    }

    try {
      int totalInventoryRecords = 0;

      // Fetch inventory summary for ALL stores in PARALLEL (not sequential!)
      // Only fetches first page but summary contains total counts from ALL items
      final futures = vendorIds.map((vendorId) async {
        try {
          final inventoryData = await getStoreInventory(vendorId, page: 0, size: 1);
          return {'vendorId': vendorId, 'data': inventoryData, 'success': true};
        } catch (e) {
          print('Error fetching stats for store $vendorId: $e');
          return {'vendorId': vendorId, 'data': null, 'success': false};
        }
      }).toList();

      // Wait for all to complete (with individual error handling)
      final results = await Future.wait(futures);

      // Process results - use summary which has totals calculated from ALL items server-side
      for (final result in results) {
        if (result['success'] == true && result['data'] != null) {
          final data = result['data'] as Map<String, dynamic>;
          final summary = data['summary'] as InventorySummary?;
          
          if (summary != null) {
            totalInventoryRecords += summary.totalItems;
          }
        }
      }

      return {
        'totalMedicines': totalInventoryRecords, // Using total items as proxy for unique medicines
        'totalInventory': totalInventoryRecords,
        'totalStores': vendorIds.length,
      };
    } catch (e) {
      print('Error calculating stats for stores: $e');
      return {
        'totalMedicines': 0,
        'totalInventory': 0,
        'totalStores': vendorIds.length,
      };
    }
  }

  /// Upload inventory from parsed Excel/CSV data with batching for large files
  /// Uses optimized bulk-upload endpoint for faster processing
  /// [onProgress] callback receives (completed, total, currentBatch, totalBatches)
  static Future<UploadResponse> uploadInventory(
    String storeId, 
    List<InventoryItem> items, {
    void Function(int completed, int total, int currentBatch, int totalBatches)? onProgress,
  }) async {
    // Use larger batch size with bulk endpoint (handles 10k+ items efficiently)
    const int batchSize = 2000; // Upload 2000 items at a time with bulk endpoint
    final int totalItems = items.length;
    final int totalBatches = (totalItems / batchSize).ceil();
    
    print('Uploading $totalItems items in $totalBatches batches to store $storeId (using bulk endpoint)');
    
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

        // Use bulk-upload endpoint for optimized batch processing
        final response = await http
            .post(
              Uri.parse(ApiConfig.bulkUploadUrl),
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            )
            .timeout(const Duration(seconds: 180)); // 3 min timeout for large batches

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
          .delete(Uri.parse(ApiConfig.deleteInventoryItemUrl(storeId, medicineId)))
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

  // =====================================================
  // BULK DELETE
  // =====================================================

  /// Bulk delete inventory items from parsed Excel/CSV data
  /// [onProgress] callback receives (completed, total, currentBatch, totalBatches)
  static Future<BulkDeleteResponse> bulkDeleteInventory(
    String storeId,
    List<DeleteItem> items, {
    void Function(int completed, int total, int currentBatch, int totalBatches)? onProgress,
  }) async {
    const int batchSize = 1000; // Balanced batch size
    final int totalItems = items.length;
    final int totalBatches = (totalItems / batchSize).ceil();

    print('Bulk deleting $totalItems items in $totalBatches batches from store $storeId');

    int successfulDeletes = 0;
    int notFoundItems = 0;
    int failedDeletes = 0;
    List<BulkDeleteError> allErrors = [];

    for (int batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
      final int start = batchIndex * batchSize;
      final int end = (start + batchSize > totalItems) ? totalItems : start + batchSize;
      final batch = items.sublist(start, end);

      print('Deleting batch ${batchIndex + 1}/$totalBatches (items $start-$end)');
      onProgress?.call(start, totalItems, batchIndex + 1, totalBatches);

      try {
        final requestBody = json.encode({
          'storeId': storeId,
          'items': batch.map((i) => i.toJson()).toList(),
        });

        final response = await http
            .post(
              Uri.parse(ApiConfig.bulkDeleteUrl),
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            )
            .timeout(const Duration(seconds: 300)); // 5 min timeout for bulk delete

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          successfulDeletes += (data['successfulDeletes'] as int? ?? 0);
          notFoundItems += (data['notFoundItems'] as int? ?? 0);
          failedDeletes += (data['failedDeletes'] as int? ?? 0);

          if (data['errors'] != null) {
            final errors = (data['errors'] as List)
                .map((e) => BulkDeleteError.fromJson(e as Map<String, dynamic>))
                .toList();
            allErrors.addAll(errors);
          }
          print('Batch ${batchIndex + 1} completed successfully');
        } else {
          print('Batch ${batchIndex + 1} failed: ${response.statusCode}');
          failedDeletes += batch.length;
          allErrors.add(BulkDeleteError(
            productName: 'Batch ${batchIndex + 1}',
            error: 'Failed with status ${response.statusCode}',
          ));
        }
      } catch (e) {
        print('Error deleting batch ${batchIndex + 1}: $e');
        failedDeletes += batch.length;
        allErrors.add(BulkDeleteError(
          productName: 'Batch ${batchIndex + 1}',
          error: 'Error: $e',
        ));
      }
    }

    onProgress?.call(totalItems, totalItems, totalBatches, totalBatches);

    return BulkDeleteResponse(
      success: failedDeletes == 0,
      message:
          'Bulk delete completed: $successfulDeletes deleted, $notFoundItems not found${failedDeletes > 0 ? ", $failedDeletes failed" : ""}',
      totalItems: totalItems,
      successfulDeletes: successfulDeletes,
      notFoundItems: notFoundItems,
      failedDeletes: failedDeletes,
      errors: allErrors,
    );
  }

  // =====================================================
  // BULK DEDUCTION (Reduce Stock)
  // =====================================================

  /// Deduct inventory from parsed Excel/CSV data with batching for large files
  /// Similar to uploadInventory but SUBTRACTS stock instead of adding
  /// [onProgress] callback receives (completed, total, currentBatch, totalBatches)
  static Future<DeductionResponse> deductInventory(
    String storeId,
    List<DeductionItem> items, {
    bool removeZeroStockItems = false,
    void Function(int completed, int total, int currentBatch, int totalBatches)? onProgress,
  }) async {
    const int batchSize = 500; // Smaller batches for deduction (more validation per item)
    final int totalItems = items.length;
    final int totalBatches = (totalItems / batchSize).ceil();

    print('Deducting $totalItems items in $totalBatches batches from store $storeId');

    // Aggregate results across batches
    int successfulDeductions = 0;
    int itemsSetToZero = 0;
    int itemsRemoved = 0;
    int failedItems = 0;
    int skippedItems = 0;
    List<DeductionResult> allResults = [];
    List<DeductionError> allErrors = [];

    for (int batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
      final int start = batchIndex * batchSize;
      final int end = (start + batchSize > totalItems) ? totalItems : start + batchSize;
      final batch = items.sublist(start, end);

      print('Deducting batch ${batchIndex + 1}/$totalBatches (items $start-$end)');
      onProgress?.call(start, totalItems, batchIndex + 1, totalBatches);

      try {
        final requestBody = json.encode({
          'storeId': storeId,
          'removeZeroStockItems': removeZeroStockItems,
          'items': batch.map((i) => i.toJson()).toList(),
        });

        final response = await http
            .post(
              Uri.parse(ApiConfig.deductUrl),
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            )
            .timeout(const Duration(seconds: 120)); // 2 min timeout

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          successfulDeductions += (data['successfulDeductions'] as int? ?? 0);
          itemsSetToZero += (data['itemsSetToZero'] as int? ?? 0);
          itemsRemoved += (data['itemsRemoved'] as int? ?? 0);
          failedItems += (data['failedItems'] as int? ?? 0);
          skippedItems += (data['skippedItems'] as int? ?? 0);

          if (data['results'] != null) {
            final results = (data['results'] as List)
                .map((e) => DeductionResult.fromJson(e as Map<String, dynamic>))
                .toList();
            allResults.addAll(results);
          }
          if (data['errors'] != null) {
            final errors = (data['errors'] as List)
                .map((e) => DeductionError.fromJson(e as Map<String, dynamic>))
                .toList();
            allErrors.addAll(errors);
          }
          print('Batch ${batchIndex + 1} completed successfully');
        } else {
          print('Batch ${batchIndex + 1} failed: ${response.statusCode}');
          failedItems += batch.length;
          allErrors.add(DeductionError(
            errorMessage: 'Batch ${batchIndex + 1} failed with status ${response.statusCode}',
            errorCode: 'BATCH_FAILED',
          ));
        }
      } catch (e) {
        print('Error deducting batch ${batchIndex + 1}: $e');
        failedItems += batch.length;
        allErrors.add(DeductionError(
          errorMessage: 'Batch ${batchIndex + 1} failed: $e',
          errorCode: 'BATCH_ERROR',
        ));
      }
    }

    onProgress?.call(totalItems, totalItems, totalBatches, totalBatches);

    return DeductionResponse(
      success: failedItems == 0,
      message:
          'Deduction completed. $successfulDeductions successful, $itemsSetToZero set to zero, $itemsRemoved removed${failedItems > 0 ? ", $failedItems failed" : ""}${skippedItems > 0 ? ", $skippedItems skipped" : ""}',
      totalItems: totalItems,
      successfulDeductions: successfulDeductions,
      itemsSetToZero: itemsSetToZero,
      itemsRemoved: itemsRemoved,
      failedItems: failedItems,
      skippedItems: skippedItems,
      results: allResults,
      errors: allErrors,
    );
  }

  /// Deduct stock for a single item (quick deduction without Excel)
  static Future<Map<String, dynamic>> deductSingleItem(
    String storeId,
    String medicineId,
    int quantity, {
    String? reason,
  }) async {
    try {
      var uri = Uri.parse(ApiConfig.deductSingleUrl(storeId, medicineId));
      uri = uri.replace(queryParameters: {
        'quantity': quantity.toString(),
        if (reason != null) 'reason': reason,
      });

      final response = await http
          .post(uri, headers: {'Content-Type': 'application/json'})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body);
        return {
          'success': false,
          'error': data['error'] ?? 'Bad request',
          'availableStock': data['availableStock'],
          'requestedDeduction': data['requestedDeduction'],
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'Medicine not found in store inventory',
        };
      }
      return {
        'success': false,
        'error': 'Request failed with status ${response.statusCode}',
      };
    } catch (e) {
      print('Error deducting single item: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}

