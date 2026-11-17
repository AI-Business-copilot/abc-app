import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:abc_app/core/config/server_address_store.dart';
import 'package:abc_app/core/theme/app_theme.dart';

/// Màn hình Cài đặt: cho phép đổi địa chỉ backend lúc chạy mà không cần build lại app.
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _controller = TextEditingController();
  bool _isLoading = true;
  bool _isTesting = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final effective = await ServerAddressStore.effective();
    if (!mounted) return;
    setState(() {
      _controller.text = effective;
      _isLoading = false;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  Future<void> _save() async {
    final error = await ServerAddressStore.write(_controller.text);
    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }
    _showMessage('Đã lưu địa chỉ backend.');
  }

  Future<void> _reset() async {
    await ServerAddressStore.clear();
    if (!mounted) return;
    setState(() {
      _controller.text = ServerAddressStore.defaultBaseUrl;
      _message = null;
      _messageIsError = false;
    });
  }

  Future<void> _testConnection() async {
    final url = ServerAddressStore.normalize(_controller.text);
    final error = ServerAddressStore.validate(url);
    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }

    setState(() {
      _isTesting = true;
      _message = null;
    });

    final dio = Dio(BaseOptions(
      baseUrl: url,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));

    try {
      final response = await dio.get('/health');
      final body = response.data is Map ? (response.data as Map)['status'] : null;
      _showMessage('Kết nối thành công${body != null ? ' ($body)' : ''}.');
    } catch (e) {
      _showMessage('Không kết nối được: ${_describeError(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  String _describeError(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'hết thời gian chờ';
        case DioExceptionType.connectionError:
          return 'không kết nối được tới máy chủ';
        case DioExceptionType.badResponse:
          return 'máy chủ trả về lỗi ${error.response?.statusCode}';
        default:
          return error.message ?? 'lỗi không xác định';
      }
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt máy chủ')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Địa chỉ backend',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.url,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'http://192.168.100.195:5000/api',
                      prefixIcon: Icon(Icons.dns_outlined, size: 18, color: AppTheme.muted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ServerAddressStore.suggestions
                        .map(
                          (s) => ActionChip(
                            label: Text('${s.label} · ${s.url}'),
                            labelStyle: const TextStyle(fontSize: 11.5),
                            onPressed: () {
                              setState(() {
                                _controller.text = s.url;
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  if (_message != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _messageIsError ? AppTheme.dangerBg : AppTheme.successBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (_messageIsError ? AppTheme.danger : AppTheme.success)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _messageIsError
                                ? Icons.error_outline_rounded
                                : Icons.check_circle_outline_rounded,
                            color: _messageIsError ? AppTheme.danger : AppTheme.success,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _message!,
                              style: TextStyle(
                                color: _messageIsError ? AppTheme.danger : AppTheme.success,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton(
                    onPressed: _isTesting ? null : _testConnection,
                    child: _isTesting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Kiểm tra kết nối'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _save,
                          child: const Text('Lưu'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _reset,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.border),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          child: const Text('Đặt lại'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Địa chỉ đã lưu sẽ được dùng cho mọi request tới backend, kể cả khi bạn đăng nhập.',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ],
              ),
            ),
    );
  }
}
