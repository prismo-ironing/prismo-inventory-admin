class ApiConfig {
  // Environment toggle - set to true for local development
  static const bool _isDevelopment = false;
  
  // Development URL (localhost)
  static const String _devBaseUrl = 'http://localhost:8081/api';
  
  // Production URL (GCP Cloud Run)
  static const String _prodBaseUrl = 'https://prismo-service-184530546940.us-central1.run.app/api';
  
  // Active base URL
  static String get baseUrl => _isDevelopment ? _devBaseUrl : _prodBaseUrl;
  
  // =====================================================
  // MANAGER AUTHENTICATION ENDPOINTS
  // =====================================================
  
  static String get managersUrl => '$baseUrl/admin/managers';
  
  // Register new manager (POST)
  static String get managerRegisterUrl => '$managersUrl/register';
  
  // Login with phone number (POST) - after Firebase OTP
  static String get managerPhoneLoginUrl => '$managersUrl/login/phone';
  
  // Login with email/password (POST)
  static String get managerEmailLoginUrl => '$managersUrl/login';
  
  // Register with email/password (POST)
  static String get managerEmailRegisterUrl => '$managersUrl/register/email';
  
  // Set password for existing manager (POST)
  static String managerSetPasswordUrl(String managerId) => '$managersUrl/$managerId/password';
  
  // Get manager by ID (GET)
  static String managerByIdUrl(String managerId) => '$managersUrl/$managerId';
  
  // Get manager by phone (GET)
  static String managerByPhoneUrl(String phoneNumber) => '$managersUrl/by-phone/$phoneNumber';
  
  // Update manager profile (PUT)
  static String managerUpdateUrl(String managerId) => '$managersUrl/$managerId';
  
  // Get manager for a vendor (GET)
  static String managerForVendorUrl(String vendorId) => '$managersUrl/vendor/$vendorId';
  
  // =====================================================
  // ADMIN INVENTORY ENDPOINTS
  // =====================================================
  
  static String get adminInventoryUrl => '$baseUrl/admin/inventory';
  
  // Stores (all)
  static String get storesUrl => '$adminInventoryUrl/stores';
  
  // Stores filtered by IDs
  static String storesByIdsUrl(List<String> ids) => 
      '$adminInventoryUrl/stores?ids=${ids.join(",")}';
  
  // Upload endpoint (regular)
  static String get uploadUrl => '$adminInventoryUrl/upload';
  
  // Bulk upload endpoint (optimized for large uploads)
  static String get bulkUploadUrl => '$adminInventoryUrl/bulk-upload';
  
  // Store inventory (with pagination support)
  static String storeInventoryUrl(String storeId, {int page = 0, int size = 50}) => 
      '$adminInventoryUrl/store/$storeId?page=$page&size=$size';
  
  // Store alerts
  static String storeAlertsUrl(String storeId) => '$adminInventoryUrl/store/$storeId/alerts';
  
  // Stats
  static String get statsUrl => '$adminInventoryUrl/stats';
  
  // Medicines endpoint
  static String get medicinesUrl => '$baseUrl/medicines';
  
  // Search medicines
  static String searchMedicinesUrl(String query) => '$medicinesUrl/search?query=$query';
}

