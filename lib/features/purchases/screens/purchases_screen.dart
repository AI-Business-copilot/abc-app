import 'package:flutter/material.dart';
import '../../../core/auth/permission_gate.dart';
import '../../commerce/models/commerce_models.dart';
import '../../commerce/services/commerce_service.dart';
import '../../commerce/widgets/commerce_widgets.dart';
import 'purchase_order_screens.dart';
import 'purchase_receipt_screens.dart';
import 'suppliers_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});
  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final api = PurchasesService();
  int revision = 0;
  @override
  Widget build(BuildContext viewContext) {
    if (!canPurchaseRead) {
      return const PermissionDeniedView(
        message: 'Mua hàng cần quyền xem kho và xem tài chính.',
      );
    }
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Đơn đặt mua'),
              Tab(text: 'Phiếu nhận'),
              Tab(text: 'Nhà cung cấp'),
              Tab(text: 'Ca thanh toán'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                CommerceList(
                  key: ValueKey(revision),
                  load: api.orders,
                  statuses: const [
                    'DRAFT',
                    'ORDERED',
                    'PARTIALLY_RECEIVED',
                    'COMPLETED',
                    'CLOSED_SHORT',
                    'CANCELLED',
                  ],
                  supplierFilter: true,
                  header: canPurchaseWrite
                      ? TextButton.icon(
                          onPressed: () async {
                            final id = await openCommerce<String>(
                              context,
                              PurchaseOrderEditor(api: api),
                            );
                            if (!mounted) return;
                            setState(() => revision++);
                            if (id != null) {
                              await openCommerce(
                                context,
                                PurchaseOrderDetail(api: api, id: id),
                              );
                            }
                            if (mounted) setState(() => revision++);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Tạo đơn đặt mua'),
                        )
                      : null,
                  tile: (o, reload) => Card(
                    child: ListTile(
                      title: Text(
                        '${o['poCode']} · ${statusLabel(o['status'])}',
                      ),
                      subtitle: Text(
                        '${object(o['supplier'])['name']} · ${dayOf(o['orderDate'])}\nĐã nhận ${object(o['totals'])['receivedQty']}/${object(o['totals'])['orderedQty']} · ${moneyLabel(object(o['totals'])['orderedAmount'])}\nCòn nợ: ${moneyLabel(object(o['totals'])['debtAmount'])}',
                      ),
                      isThreeLine: true,
                      onTap: () async {
                        await openCommerce(
                          context,
                          PurchaseOrderDetail(api: api, id: textOf(o['id'])),
                        );
                        reload();
                      },
                    ),
                  ),
                ),
                CommerceList(
                  load: api.receipts,
                  statuses: const ['RECEIVED', 'CANCELLED'],
                  supplierFilter: true,
                  tile: (r, reload) => Card(
                    child: ListTile(
                      title: Text(
                        '${r['receiptCode']} · ${statusLabel(r['status'])}',
                      ),
                      subtitle: Text(
                        '${object(r['supplier'])['name']} · ${dayOf(r['receivedAt'])}\nTiền hàng ${moneyLabel(r['totalAmount'])} · Còn nợ ${moneyLabel(r['debtAmount'])}',
                      ),
                      isThreeLine: true,
                      onTap: () async {
                        await openCommerce(
                          context,
                          PurchaseReceiptDetail(api: api, id: textOf(r['id'])),
                        );
                        reload();
                      },
                    ),
                  ),
                ),
                const SuppliersScreen(),
                ListView(
                  children: [ShiftPanel(service: api, domain: 'purchases')],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
