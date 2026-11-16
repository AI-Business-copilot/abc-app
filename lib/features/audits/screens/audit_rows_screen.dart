import 'package:flutter/material.dart';
import 'package:abc_app/core/network/api_error.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/utils/image_url.dart';
import 'package:abc_app/core/widgets/app_widgets.dart';
import 'package:abc_app/features/audits/models/audit_models.dart';
import 'package:abc_app/features/audits/services/audits_service.dart';

/// One draft row of the audit row editor.
class AuditRowDraft {
  String key;
  String assignedToUserId;
  AuditProductOption? product;
  VariantOption? variant;
  String lotItemId;

  AuditRowDraft({
    required this.key,
    required this.assignedToUserId,
    this.product,
    this.variant,
    this.lotItemId = '',
  });

  bool get isComplete =>
      assignedToUserId.isNotEmpty && product != null && variant != null;
}

/// F07 — the owner adds rows: employee -> SKU -> existing lot (re-audit only).
class AuditRowsScreen extends StatefulWidget {
  const AuditRowsScreen({
    super.key,
    required this.auditId,
    required this.auditType,
  });

  final String auditId;
  final AuditType auditType;

  @override
  State<AuditRowsScreen> createState() => _AuditRowsScreenState();
}

class _AuditRowsScreenState extends State<AuditRowsScreen> {
  final _service = AuditsService();

  List<StaffMember> _members = [];
  List<AuditRowDraft> _rows = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final members = await _service.getMembers();
      if (!mounted) return;
      setState(() {
        _members = members.where((m) => m.isAssignable).toList();
        _rows = [
          AuditRowDraft(
            key: 'row-0',
            assignedToUserId: _members.isNotEmpty ? _members.first.userId : '',
          ),
        ];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addRow() {
    setState(() {
      final previous = _rows.isNotEmpty ? _rows.last.assignedToUserId : '';
      _rows = [
        ..._rows,
        AuditRowDraft(
          key: 'row-${DateTime.now().microsecondsSinceEpoch}',
          assignedToUserId: previous,
        ),
      ];
    });
  }

  void _removeRow(String key) {
    setState(() => _rows = _rows.where((row) => row.key != key).toList());
  }

  Future<void> _save() async {
    if (widget.auditType == AuditType.reAudit) {
      final blocked = _rows
          .where((row) => row.product != null && !row.product!.hasLotTracking)
          .toList();
      if (blocked.isNotEmpty) {
        setState(
          () => _error =
              'Sản phẩm "${blocked.first.product!.name}" không quản lý lô nên không thể kiểm kê lại. Hãy dùng kiểm kê lô mới.',
        );
        return;
      }
    }
    final complete = _rows.where((row) => row.isComplete).toList();
    if (complete.isEmpty) {
      setState(() => _error = 'Cần ít nhất một dòng có nhân viên và SKU.');
      return;
    }
    if (widget.auditType == AuditType.reAudit) {
      final missingLot = complete.any((row) => row.lotItemId.isEmpty);
      if (missingLot) {
        setState(() => _error = 'Kiểm kê lại bắt buộc chọn lô có sẵn cho mỗi dòng.');
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final assignments = complete
          .map(
            (row) => AuditItemAssignment(
              assignedToUserId: row.assignedToUserId,
              variantId: row.variant!.id,
              lotItemId: row.lotItemId.isEmpty ? null : row.lotItemId,
            ),
          )
          .toList();
      await _service.addItems(widget.auditId, assignments);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Thêm dòng kiểm kê'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_error != null) MessageBanner(message: _error!, isError: true),
                        Text(
                          widget.auditType == AuditType.reAudit
                              ? 'Mỗi dòng gồm nhân viên, SKU và một lô có sẵn.'
                              : 'Mỗi dòng gồm nhân viên và SKU. Nhân viên nhập số lô khi đếm.',
                          style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                        ),
                        const SizedBox(height: 12),
                        for (var index = 0; index < _rows.length; index++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _RowEditorCard(
                              index: index,
                              row: _rows[index],
                              members: _members,
                              auditType: widget.auditType,
                              onChanged: (updated) => setState(() {
                                final rows = [..._rows];
                                rows[index] = updated;
                                _rows = rows;
                              }),
                              onRemove: () => _removeRow(_rows[index].key),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: _addRow,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Thêm dòng'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Lưu dòng kiểm kê'),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RowEditorCard extends StatefulWidget {
  const _RowEditorCard({
    required this.index,
    required this.row,
    required this.members,
    required this.auditType,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final AuditRowDraft row;
  final List<StaffMember> members;
  final AuditType auditType;
  final ValueChanged<AuditRowDraft> onChanged;
  final VoidCallback onRemove;

  @override
  State<_RowEditorCard> createState() => _RowEditorCardState();
}

class _RowEditorCardState extends State<_RowEditorCard> {
  final _service = AuditsService();

  final _productController = TextEditingController();
  List<AuditProductOption> _products = [];
  List<VariantOption> _skus = [];
  List<VariantLot> _lots = [];
  bool _isSearching = false;
  bool _isLoadingSkus = false;
  bool _isLoadingLots = false;
  int _lastSearch = 0;

  bool get _isReAudit => widget.auditType == AuditType.reAudit;

  /// A re-audit may only target products that track lots.
  bool get _blocksLotTracking =>
      _isReAudit && widget.row.product != null && !widget.row.product!.hasLotTracking;

  @override
  void initState() {
    super.initState();
    final product = widget.row.product;
    if (product == null) {
      _searchProducts('');
    } else if (!_blocksLotTracking) {
      _loadSkus(product.id);
    }
  }

  @override
  void didUpdateWidget(covariant _RowEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.row.product?.id;
    final current = widget.row.product?.id;
    if (previous != current) {
      _skus = [];
      _lots = [];
      if (current != null && !_blocksLotTracking) {
        _loadSkus(current);
      }
    }
  }

  @override
  void dispose() {
    _productController.dispose();
    super.dispose();
  }

  Future<void> _searchProducts(String keyword) async {
    final stamp = ++_lastSearch;
    setState(() => _isSearching = true);
    try {
      final products = await _service.getAuditProducts(search: keyword);
      if (!mounted || stamp != _lastSearch) return;
      setState(() => _products = products);
    } catch (_) {
      if (!mounted || stamp != _lastSearch) return;
      setState(() => _products = []);
    } finally {
      if (mounted && stamp == _lastSearch) setState(() => _isSearching = false);
    }
  }

  Future<void> _loadSkus(String productId) async {
    setState(() => _isLoadingSkus = true);
    try {
      final skus = await _service.getProductVariants(productId);
      if (!mounted) return;
      setState(() => _skus = skus);
    } catch (_) {
      if (!mounted) return;
      setState(() => _skus = []);
    } finally {
      if (mounted) setState(() => _isLoadingSkus = false);
    }
  }

  Future<void> _loadLots(String variantId) async {
    setState(() => _isLoadingLots = true);
    try {
      final lots = await _service.getLots(variantId);
      if (!mounted) return;
      setState(() => _lots = lots);
    } catch (_) {
      if (!mounted) return;
      setState(() => _lots = []);
    } finally {
      if (mounted) setState(() => _isLoadingLots = false);
    }
  }

  void _update(AuditRowDraft row) => widget.onChanged(row);

  void _selectProduct(AuditProductOption product) {
    // A new product means the old SKU and lot no longer belong to this row.
    _update(AuditRowDraft(
      key: widget.row.key,
      assignedToUserId: widget.row.assignedToUserId,
      product: product,
    ));
    setState(() {
      _products = [];
      _productController.clear();
    });
  }

  void _clearProduct() {
    _update(AuditRowDraft(
      key: widget.row.key,
      assignedToUserId: widget.row.assignedToUserId,
    ));
    setState(() {
      _skus = [];
      _lots = [];
      _productController.clear();
    });
    _searchProducts('');
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dòng ${widget.index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.primary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.danger),
                onPressed: widget.onRemove,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: row.assignedToUserId.isEmpty ? null : row.assignedToUserId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Nhân viên'),
            items: widget.members
                .map(
                  (member) => DropdownMenuItem(
                    value: member.userId,
                    child: Text(
                      member.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              _update(AuditRowDraft(
                key: row.key,
                assignedToUserId: value ?? '',
                product: row.product,
                variant: row.variant,
                lotItemId: row.lotItemId,
              ));
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Sản phẩm *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
          ),
          const SizedBox(height: 6),
          if (row.product != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  _ProductThumb(imageUrl: row.product!.imageUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.product!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        Text(
                          '${row.product!.skuCount} SKU',
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(onPressed: _clearProduct, child: const Text('Đổi')),
                ],
              ),
            )
          else ...[
            TextField(
              controller: _productController,
              onChanged: _searchProducts,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên hoặc mã sản phẩm',
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            if (_products.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return ListTile(
                      dense: true,
                      leading: _ProductThumb(imageUrl: product.imageUrl),
                      title: Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${product.skuCount} SKU',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                      ),
                      onTap: () => _selectProduct(product),
                    );
                  },
                ),
              ),
            ],
          ],
          if (row.product != null) ...[
            const SizedBox(height: 12),
            const Text(
              'SKU *',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
            ),
            const SizedBox(height: 6),
            if (_blocksLotTracking)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning),
                ),
                child: const Text(
                  'Sản phẩm này không quản lý lô nên không thể kiểm kê lại. Hãy dùng kiểm kê lô mới.',
                  style: TextStyle(fontSize: 12, color: AppTheme.warning),
                ),
              )
            else if (_isLoadingSkus)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_skus.isEmpty)
              const Text(
                'Sản phẩm này chưa có SKU nào.',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: row.variant?.id,
                isExpanded: true,
                decoration: const InputDecoration(),
                items: _skus
                    .map(
                      (sku) => DropdownMenuItem(
                        value: sku.id,
                        child: Text(
                          '${sku.sku}'
                          '${sku.attributeText.isEmpty ? '' : ' • ${sku.attributeText}'}'
                          ' • tồn ${sku.onHand}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  VariantOption? sku;
                  for (final item in _skus) {
                    if (item.id == value) {
                      sku = item;
                      break;
                    }
                  }
                  if (sku == null) return;
                  // A new SKU means the old lot no longer belongs to this row.
                  _update(AuditRowDraft(
                    key: row.key,
                    assignedToUserId: row.assignedToUserId,
                    product: row.product,
                    variant: sku,
                  ));
                  if (_isReAudit) {
                    _loadLots(sku.id);
                  }
                },
              ),
          ],
          if (_isReAudit && row.variant != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Lô có sẵn *',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
            ),
            const SizedBox(height: 6),
            if (_blocksLotTracking)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning),
                ),
                child: const Text(
                  'Sản phẩm này không quản lý lô nên không thể kiểm kê lại. Hãy dùng kiểm kê lô mới.',
                  style: TextStyle(fontSize: 12, color: AppTheme.warning),
                ),
              )
            else if (_isLoadingLots)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_lots.isEmpty)
              const Text(
                'SKU này không có lô nào.',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: row.lotItemId.isEmpty ? null : row.lotItemId,
                isExpanded: true,
                decoration: const InputDecoration(),
                items: _lots
                    .map(
                      (lot) => DropdownMenuItem(
                        value: lot.id,
                        enabled: !lot.isBlocked,
                        child: Text(
                          '${lot.lotNumber} • HSD ${formatDay(lot.expirationDate)} • tồn ${lot.onHand}'
                          '${lot.isScrapped ? ' — đã hủy hàng' : ''}'
                          '${lot.hasOpenScrapOrder ? ' — đang có phiếu hủy' : ''}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: lot.isBlocked ? AppTheme.subtle : AppTheme.primary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  _update(AuditRowDraft(
                    key: row.key,
                    assignedToUserId: row.assignedToUserId,
                    product: row.product,
                    variant: row.variant,
                    lotItemId: value ?? '',
                  ));
                },
              ),
          ],
          if (!_isReAudit && row.variant != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Lô mới: nhân viên nhập số lô và hạn sử dụng khi đếm.',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// A 40x40 product thumbnail with a placeholder when the product has no image.
class _ProductThumb extends StatelessWidget {
  const _ProductThumb({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = primaryImageUrl(imageUrl);
    if (url == null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.inventory_2_outlined, size: 20, color: AppTheme.subtle),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 40,
          height: 40,
          color: AppTheme.background,
          child: const Icon(Icons.broken_image_outlined, size: 18, color: AppTheme.subtle),
        ),
      ),
    );
  }
}
