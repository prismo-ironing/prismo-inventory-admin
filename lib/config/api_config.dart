class ApiConfig {
  // Change this to your backend URL
  static const String baseUrl = 'http://localhost:8081/api';
  
  // Admin endpoints
  static String get adminInventoryUrl => '$baseUrl/admin/inventory';
  
  // Stores
  static String get storesUrl => '$adminInventoryUrl/stores';
  
  // Upload endpoint
  static String get uploadUrl => '$adminInventoryUrl/upload';
  
  // Store inventory
  static String storeInventoryUrl(String storeId) => '$adminInventoryUrl/store/$storeId';
  
  // Store alerts
  static String storeAlertsUrl(String storeId) => '$adminInventoryUrl/store/$storeId/alerts';
  
  // Stats
  static String get statsUrl => '$adminInventoryUrl/stats';
  
  // Medicines endpoint
  static String get medicinesUrl => '$baseUrl/medicines';
  
  // Search medicines
  static String searchMedicinesUrl(String query) => '$medicinesUrl/search?query=$query';
}

