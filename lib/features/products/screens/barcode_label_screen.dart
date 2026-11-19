import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import '../models/product_model.dart';

class BarcodeLabelScreen extends StatefulWidget {
  final ProductItem product;
  final ProductVariant variant;

  const BarcodeLabelScreen({
    super.key,
    required this.product,
    required this.variant,
  });

  @override
  State<BarcodeLabelScreen> createState() => _BarcodeLabelScreenState();
}

class _BarcodeLabelScreenState extends State<BarcodeLabelScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  int _printCopies = 1;

  String get _displayBarcode {
    final b = widget.variant.barcode;
    if (b != null && b.isNotEmpty) return b;
    return widget.variant.sku;
  }

  Future<void> _printLabel() async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(2 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                widget.product.name,
                maxLines: 1,
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                'Phân loại: ${widget.variant.title}',
                style: const pw.TextStyle(fontSize: 6),
              ),
              pw.SizedBox(height: 2),
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: _displayBarcode,
                width: 40 * PdfPageFormat.mm,
                height: 12 * PdfPageFormat.mm,
                drawText: true,
                textStyle: const pw.TextStyle(fontSize: 6),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Giá: ${_currencyFormat.format(widget.variant.basePrice)}',
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Tem_${widget.variant.sku}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Xem trước & In tem nhãn'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bản xem trước tem nhãn (50mm x 30mm)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.muted),
              ),
              const SizedBox(height: 12),

              // Preview Card (Giả lập tem dán thực tế)
              Center(
                child: Container(
                  width: 260,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Phân loại: ${widget.variant.title}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                      const SizedBox(height: 10),
                      BarcodeWidget(
                        barcode: Barcode.code128(),
                        data: _displayBarcode,
                        height: 55,
                        width: 200,
                        drawText: true,
                        style: const TextStyle(fontSize: 11, letterSpacing: 1),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Giá: ${_currencyFormat.format(widget.variant.basePrice)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Controls
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
                    const Text(
                      'Cấu hình in tem',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Số lượng tem in: ', style: TextStyle(fontSize: 13)),
                        const Spacer(),
                        IconButton(
                          onPressed: _printCopies > 1
                              ? () => setState(() => _printCopies--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                        ),
                        Text(
                          '$_printCopies',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _printCopies++),
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _printLabel,
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('In tem hoặc Xuất PDF'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
