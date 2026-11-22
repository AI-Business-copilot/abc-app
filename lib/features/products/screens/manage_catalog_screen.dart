import 'package:flutter/material.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import '../models/category_attribute_model.dart';
import '../services/products_service.dart';

class ManageCatalogScreen extends StatefulWidget {
  const ManageCatalogScreen({super.key});

  @override
  State<ManageCatalogScreen> createState() => _ManageCatalogScreenState();
}

class _ManageCatalogScreenState extends State<ManageCatalogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _productsService = ProductsService();

  List<CategoryItem> _categories = [];
  List<AttributeItem> _attributes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final cats = await _productsService.getCategories();
      final attrs = await _productsService.getAttributes();
      if (mounted) {
        setState(() {
          _categories = cats;
          _attributes = attrs;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    String? selectedParentId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Thêm danh mục mới', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Tên danh mục *'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedParentId,
                decoration: const InputDecoration(labelText: 'Danh mục cha (Tùy chọn)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Không có (Cấp 1)')),
                  ..._categories.where((c) => c.parentId == null).map((c) {
                    return DropdownMenuItem(value: c.id, child: Text(c.name));
                  }),
                ],
                onChanged: (val) {
                  setDialogState(() {
                    selectedParentId = val;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: AppTheme.muted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await _productsService.createCategory(
                    name: name,
                    parentId: selectedParentId,
                  );
                  _loadData();
                } catch (e) {
                  if (mounted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi tạo danh mục: $e')),
                    );
                  }
                }
              },
              child: const Text('Tạo danh mục'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddAttributeDialog() async {
    final nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Thêm thuộc tính mới', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tên thuộc tính *',
            hintText: 'Ví dụ: Kích cỡ, Màu sắc, Chất liệu...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppTheme.muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _productsService.createAttribute(name: name);
                _loadData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi tạo thuộc tính: $e')),
                  );
                }
              }
            },
            child: const Text('Tạo thuộc tính'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddAttributeValueDialog(AttributeItem attribute) async {
    final valController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Thêm giá trị cho "${attribute.name}"', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        content: TextField(
          controller: valController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Giá trị mới *',
            hintText: 'Ví dụ: S, M, L hoặc Đỏ, Xanh...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppTheme.muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = valController.text.trim();
              if (val.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _productsService.addAttributeValue(
                  attributeId: attribute.id,
                  value: val,
                );
                _loadData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi thêm giá trị: $e')),
                  );
                }
              }
            },
            child: const Text('Thêm giá trị'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Danh mục & Thuộc tính'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          indicatorColor: AppTheme.primary,
          tabs: [
            Tab(text: 'Danh mục (${_categories.length})'),
            Tab(text: 'Thuộc tính (${_attributes.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoriesTab(),
                _buildAttributesTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddCategoryDialog();
          } else {
            _showAddAttributeDialog();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    if (_categories.isEmpty) {
      return const Center(child: Text('Chưa có danh mục nào. Bấm dấu + để thêm.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _categories.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final cat = _categories[index];
        final isChild = cat.parentId != null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Icon(
                isChild ? Icons.subdirectory_arrow_right_rounded : Icons.folder_outlined,
                size: 20,
                color: isChild ? AppTheme.muted : AppTheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.primary),
                    ),
                    if (isChild && cat.parentName != null)
                      Text(
                        'Thuộc: ${cat.parentName}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttributesTab() {
    if (_attributes.isEmpty) {
      return const Center(child: Text('Chưa có thuộc tính nào. Bấm dấu + để thêm.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _attributes.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final attr = _attributes[index];

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    attr.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primary),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => _showAddAttributeValueDialog(attr),
                    child: const Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 15, color: AppTheme.accent),
                        SizedBox(width: 4),
                        Text('Thêm giá trị', style: TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (attr.values.isEmpty)
                const Text('Chưa có giá trị nào (ví dụ: S, M, L)', style: TextStyle(fontSize: 11.5, color: AppTheme.subtle))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: attr.values.map((v) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        v.value,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.primary),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}
