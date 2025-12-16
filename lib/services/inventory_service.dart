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

  /// Upload inventory from parsed Excel data
  static Future<UploadResponse> uploadInventory(String storeId, List<InventoryItem> items) async {
    try {
      final requestBody = json.encode({
        'storeId': storeId,
        'items': items.map((i) => i.toJson()).toList(),
      });

      print('Uploading ${items.length} items to store $storeId');

      final response = await http
          .post(
            Uri.parse(ApiConfig.uploadUrl),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 60));

      print('Upload response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UploadResponse.fromJson(data);
      } else {
        final data = json.decode(response.body);
        return UploadResponse(
          success: false,
          message: data['error'] ?? 'Upload failed with status ${response.statusCode}',
          totalItems: 0,
          newMedicinesAdded: 0,
          existingMedicinesUpdated: 0,
          inventoryItemsCreated: 0,
          inventoryItemsUpdated: 0,
          failedItems: items.length,
          errors: [],
        );
      }
    } catch (e) {
      print('Error uploading inventory: $e');
      return UploadResponse(
        success: false,
        message: 'Error uploading: $e',
        totalItems: 0,
        newMedicinesAdded: 0,
        existingMedicinesUpdated: 0,
        inventoryItemsCreated: 0,
        inventoryItemsUpdated: 0,
        failedItems: items.length,
        errors: [],
      );
    }
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

