import 'package:flutter/material.dart';
import 'package:abc_app/core/network/api_error.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/widgets/app_widgets.dart';
import 'package:abc_app/core/widgets/image_viewer.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import 'package:abc_app/features/scrap/models/scrap_models.dart';
import 'package:abc_app/features/scrap/services/scrap_service.dart';

/// F08 — one scrap order with its evidence photos.
class ScrapDetailScreen extends StatefulWidget {
  const ScrapDetailScreen({super.key, required this.scrapOrderId});

  final String scrapOrderId;

  @override
  State<ScrapDetailScreen> createState() => _ScrapDetailScreenState();
}

class _ScrapDetailScreenState extends State<ScrapDetailScreen> {
  final _service = ScrapService();

  ScrapOrderDetail? _order;
  bool _isLoading = true;
  bool _isActing = false;
  bool _isEditing = false;
  String? _error;
  String? _notice;

  final _editQtyController = TextEditingController();
  final _editReasonController = TextEditingController();
  RejectionReasonCode? _reasonCode;
  final _rejectNoteController = TextEditingController();
  final _cancelNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _editQtyController.dispose();
    _editReasonController.dispose();
    _rejectNoteController.dispose();
    _cancelNoteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final order = await _service.getScrapOrder(widget.scrapOrderId);
      if (!mounted) return;
      setState(() => _order = order);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve() async {
    final order = _order;
    if (order == null) return;
    if (order.images.isEmpty) {
      setState(() => _error = 'Phiếu chưa có ảnh bằng chứng.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Duyệt hủy hàng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          'Duyệt hủy ${order.scrapQty} sản phẩm? Tồn kho sẽ giảm và tổn thất '
          '${formatMoney(order.estimatedLoss)} sẽ được ghi nhận. Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy', style: TextStyle(color: AppTheme.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Duyệt'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isActing = true;
      _error = null;
    });
    try {
      final result = await _service.approveScrapOrder(
        widget.scrapOrderId,
        order.images.map((image) => image.id).toList(),
      );
      await _load();
      if (!mounted) return;
      setState(() {
        _notice = 'Đã duyệt phiếu hủy. Tồn kho đã được cập nhật.'
            '${result.lotScrapped ? ' Lô hàng đã chuyển sang trạng thái đã hủy hàng.' : ''}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
      // A 409 usually means the photos changed: reload so the next attempt uses what is there.
      await _load();
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _reject() async {
    final code = _reasonCode;
    if (code == null) {
      setState(() => _error = 'Vui lòng chọn lý do từ chối.');
      return;
    }
    setState(() {
      _isActing = true;
      _error = null;
    });
    try {
      await _service.rejectScrapOrder(
        widget.scrapOrderId,
        reasonCode: code,
        note: _rejectNoteController.text,
      );
      await _load();
      if (!mounted) return;
      setState(() => _notice = 'Đã từ chối phiếu hủy. Lô hàng vẫn đang được cách ly.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _cancel() async {
    setState(() {
      _isActing = true;
      _error = null;
    });
    try {
      await _service.cancelScrapOrder(widget.scrapOrderId, note: _cancelNoteController.text);
      await _load();
      if (!mounted) return;
      setState(() => _notice = 'Đã hủy phiếu. Lô hàng vẫn đang được cách ly.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _saveEdit() async {
    final quantity = int.tryParse(_editQtyController.text.trim());
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'Số lượng phải là số nguyên lớn hơn 0.');
      return;
    }
    if (_editReasonController.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do hủy hàng.');
      return;
    }
    setState(() {
      _isActing = true;
      _error = null;
    });
    try {
      await _service.updateScrapOrder(
        widget.scrapOrderId,
        scrapQty: quantity,
        scrapReason: _editReasonController.text,
      );
      await _load();
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _notice = 'Đã cập nhật phiếu hủy.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Xóa phiếu hủy', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text(
          'Xóa phiếu hủy này cùng toàn bộ ảnh? Lô hàng vẫn được giữ ở trạng thái cách ly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy', style: TextStyle(color: AppTheme.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isActing = true;
      _error = null;
    });
    try {
      await _service.deleteScrapOrder(widget.scrapOrderId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(order?.scrapCode ?? 'Phiếu hủy hàng'),
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
            : order == null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: MessageBanner(
                      message: _error ?? 'Không tìm thấy phiếu hủy.',
                      isError: true,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_error != null) MessageBanner(message: _error!, isError: true),
                      if (_notice != null) MessageBanner(message: _notice!),
                      _buildStatusBanner(order),
                      const SizedBox(height: 12),
                      _buildInfoCard(order),
                      const SizedBox(height: 12),
                      _buildGallery(order),
                      if (_canEdit(order)) ...[
                        const SizedBox(height: 12),
                        _buildEditActions(),
                      ],
                      if (_canReview(order)) ...[
                        const SizedBox(height: 12),
                        _buildReviewCard(order),
                      ],
                    ],
                  ),
      ),
    );
  }

  bool _canEdit(ScrapOrderDetail order) {
    return order.status == ScrapStatus.pending &&
        AuthService.isStaff &&
        order.createdBy == AuthService.userId &&
        AuthService.hasPermission(AppPermissions.scrapCreate);
  }

  bool _canReview(ScrapOrderDetail order) {
    return order.status == ScrapStatus.pending &&
        AuthService.isOwner &&
        AuthService.hasPermission(AppPermissions.scrapApprove);
  }

  Widget _buildStatusBanner(ScrapOrderDetail order) {
    switch (order.status) {
      case ScrapStatus.completed:
        return MessageBanner(
          message:
              'Đã duyệt bởi ${order.approvedByUser?.fullName ?? '—'} lúc ${formatDateTime(order.approvedAt)}. '
              'Tổn thất ghi nhận: ${formatMoney(order.totalLossValue ?? 0)}.',
        );
      case ScrapStatus.rejected:
        final code = RejectionReasonCode.fromCode(order.rejectionReasonCode);
        return MessageBanner(
          isError: true,
          message:
              'Bị từ chối bởi ${order.rejectedByUser?.fullName ?? '—'} lúc ${formatDateTime(order.rejectedAt)}. '
              'Lý do: ${code?.label ?? '—'}'
              '${order.rejectionNote == null || order.rejectionNote!.isEmpty ? '' : ' — ${order.rejectionNote}'}',
        );
      case ScrapStatus.cancelled:
        return MessageBanner(
          message:
              'Đã hủy bởi ${order.cancelledByUser?.fullName ?? '—'} lúc ${formatDateTime(order.cancelledAt)}. '
              'Tồn kho không thay đổi và lô hàng vẫn đang được cách ly.'
              '${order.cancelledNote == null || order.cancelledNote!.isEmpty ? '' : ' — ${order.cancelledNote}'}',
        );
      case ScrapStatus.pending:
        return MessageBanner(
          message: 'Đang chờ chủ cửa hàng xem ảnh bằng chứng và quyết định.',
        );
    }
  }

  Widget _buildInfoCard(ScrapOrderDetail order) {
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
          if (_isEditing) ...[
            TextField(
              controller: _editQtyController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(labelText: 'Số lượng hủy'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _editReasonController,
              maxLines: 2,
              maxLength: 255,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(labelText: 'Lý do hủy'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isActing ? null : _saveEdit,
                    child: const Text('Lưu'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isActing
                        ? null
                        : () => setState(() => _isEditing = false),
                    child: const Text('Hủy'),
                  ),
                ),
              ],
            ),
          ] else ...[
            _Row(label: 'Sản phẩm', value: '${order.variant.productName} (${order.variant.sku})'),
            _Row(label: 'Số lô', value: order.lotItem?.lotNumber ?? '—'),
            _Row(label: 'Hạn sử dụng', value: formatDay(order.lotItem?.expirationDate)),
            _Row(label: 'Số lượng hủy', value: '${order.scrapQty}'),
            _Row(label: 'Nguồn tồn kho', value: order.scrapSource.label),
            _Row(label: 'Giá vốn / sản phẩm', value: formatMoney(order.unitCost)),
            _Row(label: 'Lý do hủy', value: order.scrapReason),
            _Row(
              label: 'Tạo bởi',
              value:
                  '${order.createdByUser?.fullName ?? '—'} • ${formatDateTime(order.createdAt)}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGallery(ScrapOrderDetail order) {
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
          Text(
            'Ảnh bằng chứng (${order.images.length})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary),
          ),
          const SizedBox(height: 10),
          if (order.images.isEmpty)
            const Text(
              'Phiếu này không có ảnh.',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: order.images.length,
              itemBuilder: (context, index) {
                final image = order.images[index];
                if (image.url == null) {
                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, size: 20, color: AppTheme.subtle),
                    ),
                  );
                }
                return GestureDetector(
                  onTap: () => _openImage(context, image),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      image.url!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppTheme.background,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 20,
                          color: AppTheme.subtle,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _openImage(BuildContext context, ScrapImage image) {
    if (image.url == null) return;
    final images = _order?.images ?? <ScrapImage>[];
    final index = images.indexWhere((item) => item.id == image.id);
    ImageViewer.show(
      context,
      images: images
          .map((item) => ViewerImage(
                id: item.id,
                url: item.url,
                caption: item.uploadedByName,
              ))
          .toList(),
      index: index < 0 ? 0 : index,
    );
  }

  Widget _buildEditActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isActing
                ? null
                : () => setState(() {
                      _editQtyController.text = '${_order!.scrapQty}';
                      _editReasonController.text = _order!.scrapReason;
                      _isEditing = true;
                    }),
            child: const Text('Sửa phiếu'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: _isActing ? null : _delete,
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Xóa phiếu'),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(ScrapOrderDetail order) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.successBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Duyệt phiếu hủy',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary),
          ),
          const SizedBox(height: 4),
          Text(
            'Xem kỹ các ảnh bằng chứng trước khi quyết định. Số lượng hủy: ${order.scrapQty} • '
            'Tổn thất dự kiến: ${formatMoney(order.estimatedLoss)}.',
            style: const TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isActing ? null : _approve,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: const Text('Duyệt hủy hàng', style: TextStyle(fontSize: 12.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 10),
          DropdownButtonFormField<RejectionReasonCode>(
            initialValue: _reasonCode,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Lý do từ chối'),
            items: RejectionReasonCode.values
                .map(
                  (code) => DropdownMenuItem(
                    value: code,
                    child: Text(code.label, style: const TextStyle(fontSize: 13.5)),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _reasonCode = value),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _rejectNoteController,
            maxLines: 2,
            maxLength: 500,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(labelText: 'Ghi chú (không bắt buộc)'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isActing ? null : _reject,
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                  child: const Text('Từ chối', style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isActing ? null : _cancel,
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                  child: const Text('Hủy phiếu', style: TextStyle(fontSize: 12.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Từ chối là quyết độc. Lô hàng vẫn đang cách ly và không thể tạo phiếu hủy mới cho lô này.',
            style: TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
