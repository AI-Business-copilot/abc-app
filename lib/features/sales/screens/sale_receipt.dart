import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../commerce/models/commerce_models.dart';
import '../../commerce/widgets/commerce_widgets.dart';

class SaleReceipt {
  static const widthKey = 'abc.receipt.width',
      automaticKey = 'abc.receipt.automatic';
  static final _claimed = <String>{};
  static Future<bool> claimAutomatic(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(automaticKey) != true) return false;
    final claim =
        'abc.receipt.claim:${prefs.getString('active_business_id') ?? ''}:$orderId';
    if (_claimed.contains(claim) || prefs.getBool(claim) == true) return false;
    _claimed.add(claim);
    // Claim before opening the print flow, even if printing fails or is cancelled.
    if (!await prefs.setBool(claim, true)) {
      throw const FormatException(
        'Không lưu được trạng thái chống in trùng. Hãy in thủ công.',
      );
    }
    return true;
  }

  static Future<Uint8List> build(
    Json order,
    int width, {
    pw.Font? font,
    String businessName = 'ABC COPILOT',
  }) async {
    if (order['status'] != 'COMPLETED') {
      throw const FormatException('Chỉ in hóa đơn của đơn đã hoàn tất.');
    }
    final normal = font ?? await PdfGoogleFonts.notoSansRegular();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: normal, bold: normal),
    );
    final pageWidth = (width == 58 ? 58 : 80) * PdfPageFormat.mm;
    pw.Widget row(String label, Object? value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Text(label)),
          pw.SizedBox(width: 5),
          pw.Text(textOf(value)),
        ],
      ),
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(
          pageWidth,
          297 * PdfPageFormat.mm,
          marginAll: 3 * PdfPageFormat.mm,
        ),
        maxPages: 1000,
        theme: pw.ThemeData.withFont(
          base: normal,
          bold: normal,
        ).copyWith(defaultTextStyle: const pw.TextStyle(fontSize: 8)),
        build: (_) => [
          pw.Center(
            child: pw.Text(
              businessName,
              style: const pw.TextStyle(fontSize: 12),
            ),
          ),
          pw.Center(child: pw.Text('HÓA ĐƠN BÁN HÀNG')),
          pw.Text('Mã đơn: ${order['orderCode']}'),
          pw.Text('Ngày: ${order['createdAt']}'),
          pw.Text(
            'Khách: ${object(order['customer'])['name'] ?? 'Khách vãng lai'}',
          ),
          if (order['customer'] != null)
            pw.Text('SĐT: ${object(order['customer'])['phone']}'),
          pw.Divider(),
          for (final item in records(order['orderItems'])) ...[
            pw.Text(variantLabel(item)),
            row(
              '${item['quantity']} × ${moneyLabel(item['unitPrice'])}',
              moneyLabel(item['subtotal']),
            ),
          ],
          pw.Divider(),
          row('Tiền hàng', moneyLabel(order['totalGrossAmount'])),
          row(
            object(order['promotionSnapshot'])['name']?.toString() ??
                'Giảm giá',
            moneyLabel(order['discountAmount']),
          ),
          row('TỔNG THANH TOÁN', moneyLabel(order['totalNetAmount'])),
          pw.Divider(),
          for (final payment in records(order['orderPayments']))
            row(
              payment['paymentMethod'] == 'CASH'
                  ? 'Tiền mặt'
                  : payment['paymentMethod'] == 'PROMOTION'
                  ? 'Khuyến mãi 100%'
                  : 'Chuyển khoản',
              moneyLabel(payment['amount']),
            ),
          pw.Center(child: pw.Text('Cảm ơn quý khách!')),
        ],
      ),
    );
    return doc.save();
  }

  static Future<bool> print(Json order) async {
    final prefs = await SharedPreferences.getInstance();
    final width = prefs.getInt(widthKey) == 58 ? 58 : 80;
    final bytes = await build(
      order,
      width,
      businessName: prefs.getString('active_business_name') ?? 'ABC COPILOT',
    );
    return Printing.layoutPdf(
      name: 'Hoa_don_${order['orderCode']}',
      format: PdfPageFormat(width * PdfPageFormat.mm, 297 * PdfPageFormat.mm),
      onLayout: (_) async => bytes,
    );
  }
}

class ReceiptSettings extends StatefulWidget {
  const ReceiptSettings({super.key});
  @override
  State<ReceiptSettings> createState() => _ReceiptSettingsState();
}

class _ReceiptSettingsState extends State<ReceiptSettings>
    with CommerceActions {
  int _width = 80;
  bool _automatic = false, _loaded = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _width = prefs.getInt(SaleReceipt.widthKey) == 58 ? 58 : 80;
        _automatic = prefs.getBool(SaleReceipt.automaticKey) == true;
        _loaded = true;
      });
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(SaleReceipt.widthKey, _width);
    await prefs.setBool(SaleReceipt.automaticKey, _automatic);
  }

  @override
  Widget build(BuildContext viewContext) => CommerceCard(
    title: 'In hóa đơn',
    children: [
      if (!_loaded) const LinearProgressIndicator(),
      DropdownButtonFormField<int>(
        isExpanded: true,
        key: ValueKey(_width),
        initialValue: _width,
        decoration: const InputDecoration(labelText: 'Khổ giấy'),
        items: const [
          DropdownMenuItem(value: 58, child: Text('58 mm')),
          DropdownMenuItem(value: 80, child: Text('80 mm')),
        ],
        onChanged: !_loaded || busy
            ? null
            : (v) => act(() async {
                setState(() => _width = v!);
                await save();
              }),
      ),
      SwitchListTile(
        title: const Text('Mở in sau khi thanh toán thành công'),
        value: _automatic,
        onChanged: !_loaded || busy
            ? null
            : (v) => act(() async {
                setState(() => _automatic = v);
                await save();
              }),
      ),
      const Text(
        'Chọn máy in và đúng khổ giấy trong hộp thoại hệ thống. Có thể in lại từ đơn đã hoàn tất. Lần in đầu cần mạng để tải phông chữ tiếng Việt.',
      ),
      ErrorNotice(actionError),
    ],
  );
}
