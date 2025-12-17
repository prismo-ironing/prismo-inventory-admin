class ApiConfig {
  // Environment toggle - set to false for production
  static const bool _isDevelopment = false;
  
  // Development URL (localhost)
  static const String _devBaseUrl = 'http://localhost:8081/api';
  
  // Production URL (GCP Cloud Run)
  static const String _prodBaseUrl = 'https://prismo-service-184530546940.us-central1.run.app/api';
  
  // Active base URL
  static String get baseUrl => _isDevelopment ? _devBaseUrl : _prodBaseUrl;
  
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

