import 'package:flutter/material.dart';
import '../../../core/auth/permission_gate.dart';
import '../../auth/services/auth_service.dart';
import '../../commerce/models/commerce_models.dart';
import '../../commerce/services/commerce_service.dart';
import '../../commerce/widgets/commerce_widgets.dart';
import 'sale_editor_screen.dart';
import 'sale_detail_screen.dart';
import 'sale_receipt.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final api = SalesService();
  int revision = 0;
  @override
  Widget build(BuildContext viewContext) {
    if (!AuthService.hasPermission('orders.read')) {
      return const PermissionDeniedView(
        message: 'Bán hàng cần quyền xem đơn bán.',
      );
    }
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Đơn bán'),
              Tab(text: 'Khách hàng'),
              Tab(text: 'Ca & In'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                CommerceList(
                  key: ValueKey(revision),
                  load: api.orders,
                  statuses: const ['DRAFT', 'COMPLETED', 'CANCELLED'],
                  header: canSaleWrite
                      ? TextButton.icon(
                          onPressed: () async {
                            await openCommerce(
                              context,
                              SaleEditorScreen(api: api),
                            );
                            if (mounted) setState(() => revision++);
                          },
                          icon: const Icon(Icons.point_of_sale),
                          label: const Text('Bán hàng tại quầy'),
                        )
                      : null,
                  tile: (o, reload) => Card(
                    child: ListTile(
                      title: Text(
                        '${o['orderCode']} · ${statusLabel(o['status'])}',
                      ),
                      subtitle: Text(
                        '${object(o['customer'])['name'] ?? 'Khách vãng lai'} · ${dayOf(o['createdAt'])}\n${moneyLabel(o['totalNetAmount'])}',
                      ),
                      onTap: () async {
                        await openCommerce(
                          context,
                          SaleDetailScreen(api: api, id: textOf(o['id'])),
                        );
                        reload();
                      },
                    ),
                  ),
                ),
                CustomersScreen(api: api),
                ListView(
                  children: [
                    ShiftPanel(service: api, domain: 'sales'),
                    const ReceiptSettings(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.api, this.picking = false});
  final SalesService api;
  final bool picking;
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  int revision = 0;
  @override
  Widget build(BuildContext viewContext) {
    final body = CommerceList(
      key: ValueKey(revision),
      dates: false,
      load: widget.api.customers,
      header: canSaleWrite
          ? TextButton.icon(
              onPressed: () async {
                final saved = await openCommerce<Json>(
                  context,
                  CustomerEditor(api: widget.api),
                );
                if (!mounted) return;
                if (saved != null && widget.picking) {
                  Navigator.pop(context, saved);
                } else {
                  setState(() => revision++);
                }
              },
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Thêm khách hàng'),
            )
          : null,
      tile: (c, _) => ListTile(
        title: Text(textOf(c['name'])),
        subtitle: Text(textOf(c['phone'])),
        onTap: widget.picking ? () => Navigator.pop(context, c) : null,
      ),
    );
    return widget.picking
        ? Scaffold(
            appBar: AppBar(title: const Text('Chọn khách hàng')),
            body: body,
          )
        : body;
  }
}

class CustomerEditor extends StatefulWidget {
  const CustomerEditor({super.key, required this.api});
  final SalesService api;
  @override
  State<CustomerEditor> createState() => _CustomerEditorState();
}

class _CustomerEditorState extends State<CustomerEditor> with CommerceActions {
  final _name = TextEditingController(), _phone = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext viewContext) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Thêm khách hàng')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CommerceField(
              _name,
              'Tên khách hàng',
              required: true,
              maxLength: 150,
            ),
            CommerceField(
              _phone,
              'Số điện thoại',
              required: true,
              maxLength: 20,
            ),
            ErrorNotice(actionError),
            FilledButton(
              onPressed: busy
                  ? null
                  : () => act(() async {
                      if (!_form.currentState!.validate()) return;
                      final saved = await widget.api.createCustomer(
                        _name.text,
                        _phone.text,
                      );
                      if (mounted) Navigator.pop(context, saved);
                    }),
              child: const Text('Lưu khách hàng'),
            ),
          ],
        ),
      ),
    ),
  );
}
