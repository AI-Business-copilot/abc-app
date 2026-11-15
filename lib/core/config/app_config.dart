class AppConfig {
  static const String supabaseUrl = 'https://vhivkicmqwjiypvbssbv.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZoaXZraWNtcXdqaXlwdmJzc2J2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIzODM2MTUsImV4cCI6MjEwNzk1OTYxNX0.HubY19CKmXVkWdac0Ngs989MAZZ0azfrA1P_OmBEmhc';

  // 1. IP mạng LAN của máy tính đang chạy backend (192.168.88.168)
  // Dành cho thiết bị THẬT cắm cáp / cùng mạng Wi-Fi
  static const String apiBaseUrlLan = 'http://192.168.88.168:5000/api';

  // 2. IP dành cho máy ảo Android Emulator
  static const String apiBaseUrlEmulator = 'http://10.0.2.2:5000/api';

  // 3. IP dành cho Windows Desktop / iOS Simulator
  static const String apiBaseUrlLocal = 'http://localhost:5000/api';
}
