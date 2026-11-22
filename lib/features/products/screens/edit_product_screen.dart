import 'package:flutter/material.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/services/upload_service.dart';
import '../models/product_model.dart';
import '../models/category_attribute_model.dart';
import '../services/products_service.dart';

class EditProductScreen extends StatefulWidget {
  final ProductItem product;

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _productsService = ProductsService();
  final _uploadService = UploadService();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  String? _imageUrl;
  String? _selectedCategoryId;

  List<CategoryItem> _categories = [];
  bool _isLoadingCategories = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _descController = TextEditingController(text: widget.product.description ?? '');
    _imageUrl = widget.product.imageUrl;
    _selectedCategoryId = widget.product.categoryId;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final list = await _productsService.getCategories();
      if (mounted) {
        setState(() {
          _categories = list;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingCategories = false);
  }

  Future<void> _pickAndUploadImage(bool fromCamera) async {
    try {
      final file = fromCamera
          ? await _uploadService.pickImageFromCamera()
          : await _uploadService.pickImageFromGallery();

      if (file == null) return;

      setState(() => _isUploadingImage = true);
      final uploadedUrl = await _uploadService.uploadImage(file);
      if (mounted && uploadedUrl != null) {
        setState(() {
          _imageUrl = uploadedUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tải ảnh lên thành công!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi upload ảnh: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên sản phẩm không được để trống')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _productsService.updateProductTemplate(
        widget.product.id,
        name: name,
        description: _descController.text.trim(),
        imageUrl: _imageUrl,
        categoryId: _selectedCategoryId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật sản phẩm thành công!')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
                title: const Text('Chụp ảnh mới bằng Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                title: const Text('Chọn ảnh từ Thư viện'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(false);
                },
              ),
              if (_imageUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
                  title: const Text('Xóa ảnh hiện tại', style: TextStyle(color: AppTheme.danger)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _imageUrl = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Chỉnh sửa thông tin hàng'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                  )
                : const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Picker Header
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                        image: _imageUrl != null && _imageUrl!.isNotEmpty
                            ? DecorationImage(image: NetworkImage(_imageUrl!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _imageUrl == null || _imageUrl!.isEmpty
                          ? const Icon(Icons.image_outlined, size: 40, color: AppTheme.subtle)
                          : null,
                    ),
                    if (_isUploadingImage)
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _isUploadingImage ? null : _showImageSourceDialog,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Chụp hoặc đổi ảnh sản phẩm', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
              ),
              const SizedBox(height: 24),

              // Product Info Form
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mã mặt hàng (Template Code)', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                    const SizedBox(height: 4),
                    Text(
                      widget.product.code,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primary),
                    ),
                    const Divider(height: 24, color: AppTheme.border),

                    const Text('Tên sản phẩm *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: const InputDecoration(hintText: 'Nhập tên sản phẩm'),
                    ),
                    const SizedBox(height: 16),

                    const Text('Danh mục hàng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    _isLoadingCategories
                        ? const LinearProgressIndicator()
                        : DropdownButtonFormField<String>(
                            initialValue: _categories.any((c) => c.id == _selectedCategoryId)
                                ? _selectedCategoryId
                                : null,
                            decoration: const InputDecoration(hintText: 'Chọn danh mục'),
                            items: _categories.map((c) {
                              return DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name, style: const TextStyle(fontSize: 13.5)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCategoryId = val;
                              });
                            },
                          ),
                    const SizedBox(height: 16),

                    const Text('Mô tả mặt hàng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: const InputDecoration(hintText: 'Nhập mô tả thêm về sản phẩm...'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
