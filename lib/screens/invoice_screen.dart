import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/database_helper.dart';
import '../models/product.dart';
import '../utils/number_format.dart';
import '../utils/persian_date.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<Map<String, dynamic>> _invoices = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> get _filteredInvoices {
    final query = _searchCtrl.text.trim().toLowerCase().replaceAll(',', '');
    if (query.isEmpty) return _invoices;
    return _invoices.where((invoice) {
      final haystack = '${invoice['invoice_number']} ${invoice['customer_name'] ?? ''} ${invoice['customer_phone'] ?? ''} ${invoice['date']} ${invoice['total']}'.toLowerCase().replaceAll(',', '');
      return haystack.contains(query);
    }).toList();
  }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DatabaseHelper.instance.getInvoices();
    if (!mounted) return;
    setState(() { _invoices = rows; _loading = false; });
  }
  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
    );
    if (created == true) _load();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('فاکتورهای فروش')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _create, icon: const Icon(Icons.add), label: const Text('فاکتور جدید'),
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'جست‌وجوی شماره، مشتری یا تاریخ فاکتور',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty ? null : IconButton(
                  tooltip: 'پاک‌کردن جست‌وجو', icon: const Icon(Icons.close),
                  onPressed: () { _searchCtrl.clear(); setState(() {}); },
                ),
              ),
            ),
          ),
          Expanded(child: _filteredInvoices.isEmpty
            ? Center(child: Text(_invoices.isEmpty ? 'هنوز فاکتوری ثبت نشده است' : 'فاکتوری با این مشخصات پیدا نشد'))
            : RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 88, top: 8),
            itemCount: _filteredInvoices.length,
            itemBuilder: (context, index) {
              final invoice = _filteredInvoices[index];
              final customer = (invoice['customer_name'] as String?)?.trim();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                  title: Text('${invoice['invoice_number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${invoice['date']} • ${customer == null || customer.isEmpty ? 'مشتری آزاد' : customer}'),
                  trailing: Text('${NumberFormatHelper.integer((invoice['total'] as num).toDouble())} ریال',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.of(context).push<void>(MaterialPageRoute(
                    builder: (_) => InvoiceDetailScreen(invoiceId: invoice['id'] as int),
                  )),
                ),
              );
            },
          ),
        )),
      ]),
  );
}

class _InvoiceLine {
  final Product product;
  final double quantity;
  final double unitPrice;
  const _InvoiceLine({required this.product, required this.quantity, required this.unitPrice});
  double get total => quantity * unitPrice;
}

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});
  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _customerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  List<Product> _products = [];
  Product? _selectedProduct;
  final List<_InvoiceLine> _lines = [];
  bool _loading = true;
  bool _saving = false;
  final String _date = PersianDateHelper.today();
  double get _subtotal => _lines.fold<double>(0, (sum, line) => sum + line.total);
  double get _discount => double.tryParse(_discountCtrl.text.replaceAll(',', '').trim()) ?? 0;
  double get _total => _subtotal - _discount;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _discountCtrl.addListener(() { if (mounted) setState(() {}); });
  }
  @override
  void dispose() {
    _customerCtrl.dispose(); _phoneCtrl.dispose(); _notesCtrl.dispose();
    _quantityCtrl.dispose(); _discountCtrl.dispose();
    super.dispose();
  }
  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    if (!mounted) return;
    setState(() {
      _products = products;
      _selectedProduct = null;
      _loading = false;
    });
  }
  void _addLine() {
    final product = _selectedProduct;
    final quantity = double.tryParse(_quantityCtrl.text.replaceAll(',', '').trim()) ?? 0;
    final price = product?.sellPrice ?? -1;
    if (product == null || quantity <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کالا، تعداد و قیمت معتبر را وارد کنید')));
      return;
    }
    setState(() {
      _lines.add(_InvoiceLine(product: product, quantity: quantity, unitPrice: price));
      _quantityCtrl.clear();
    });
  }
  Future<void> _save() async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حداقل یک کالا به فاکتور اضافه کنید')));
      return;
    }
    if (_discount < 0 || _discount > _subtotal) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تخفیف نباید از جمع کالاها بیشتر باشد')));
      return;
    }
    setState(() => _saving = true);
    try {
      for (final line in _lines) {
        final current = await DatabaseHelper.instance.getCurrentStock(line.product.code);
        if (current < line.quantity && mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('هشدار موجودی'),
              content: Text('موجودی ${line.product.name}: ${current.toStringAsFixed(2)} ${line.product.unit}\nمقدار در فاکتور: ${NumberFormatHelper.quantity(line.quantity)}\nآیا ادامه می‌دهید؟'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ادامه')),
              ],
            ),
          );
          if (proceed != true) { if (mounted) setState(() => _saving = false); return; }
        }
      }
      await DatabaseHelper.instance.insertInvoice(
        date: _date,
        customerName: _customerCtrl.text,
        customerPhone: _phoneCtrl.text,
        notes: _notesCtrl.text,
        discount: _discount,
        items: _lines.map((line) => <String, dynamic>{
          'product_code': line.product.code,
          'product_name': line.product.name,
          'unit': line.product.unit,
          'quantity': line.quantity,
          'unit_price': line.unitPrice,
        }).toList(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ثبت فاکتور ناموفق بود: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('صدور فاکتور فروش')),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : _products.isEmpty
        ? const Center(child: Text('ابتدا از بخش کالاها، کالا ثبت کنید'))
        : ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            TextField(controller: _customerCtrl, decoration: const InputDecoration(labelText: 'نام مشتری (اختیاری)', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 10),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'شماره تماس مشتری (اختیاری)', prefixIcon: Icon(Icons.phone_outlined))),
            const SizedBox(height: 10),
            InputDecorator(decoration: const InputDecoration(labelText: 'تاریخ فاکتور'), child: Text(_date)),
            const SizedBox(height: 16),
            const Text('افزودن کالا', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<Product>(
              value: _selectedProduct, isExpanded: true,
              hint: const Text('انتخاب کنید'),
              decoration: const InputDecoration(labelText: 'کالا'),
              items: _products.map((product) => DropdownMenuItem(value: product,
                child: Text('${product.code} — ${product.name}', overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (product) => setState(() { _selectedProduct = product; }),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _quantityCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(labelText: 'تعداد / مقدار', hintText: 'مثلاً 1.5 یا 2.25', helperText: 'برای کالاهای فله‌ای یا دانه‌ای'))),
              const SizedBox(width: 10),
              Expanded(child: InputDecorator(
                decoration: const InputDecoration(labelText: 'قیمت واحد (ریال)'),
                child: Text(_selectedProduct == null ? '—' : NumberFormatHelper.integer(_selectedProduct!.sellPrice),
                  textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600)),
              )),
            ]),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: _addLine, icon: const Icon(Icons.add_shopping_cart), label: const Text('افزودن به فاکتور')),
            const SizedBox(height: 16),
            const Text('اقلام فاکتور', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            if (_lines.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Text('هنوز کالایی اضافه نشده است')),
            ..._lines.asMap().entries.map((entry) {
              final line = entry.value;
              return Card(child: ListTile(
                title: Text(line.product.name),
                subtitle: Text('${NumberFormatHelper.quantity(line.quantity)} ${line.product.unit} × ${NumberFormatHelper.integer(line.unitPrice)} = ${NumberFormatHelper.integer(line.total)} ریال'),
                trailing: IconButton(tooltip: 'حذف کالا', icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _lines.removeAt(entry.key))),
              ));
            }),
            const SizedBox(height: 12),
            TextField(controller: _notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)')),
            const SizedBox(height: 16),
            _SummaryRow(label: 'جمع کالاها', value: _subtotal),
            const SizedBox(height: 8),
            TextField(controller: _discountCtrl, keyboardType: TextInputType.number,
              inputFormatters: [_ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(labelText: 'تخفیف کل (ریال)', hintText: 'مبلغ را وارد کنید', helperText: 'پس از جمع اقلام از مبلغ نهایی کسر می‌شود')),
            _SummaryRow(label: 'تخفیف', value: _discount),
            const Divider(),
            _SummaryRow(label: 'مبلغ نهایی', value: _total, bold: true),
          ],
        ),
    bottomNavigationBar: _loading || _products.isEmpty ? null : SafeArea(
      minimum: const EdgeInsets.all(12),
      child: FilledButton.icon(
        onPressed: _saving ? null : _save,
        icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
        label: Text(_saving ? 'در حال ثبت...' : 'ثبت نهایی فاکتور'),
      ),
    ),
  );
}

class InvoiceDetailScreen extends StatefulWidget {
  final int invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});
  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _working = false;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final invoice = await DatabaseHelper.instance.getInvoice(widget.invoiceId);
    final items = await DatabaseHelper.instance.getInvoiceItems(widget.invoiceId);
    if (!mounted) return;
    setState(() { _invoice = invoice; _items = items; _loading = false; });
  }
  Future<Uint8List> _buildPdf() async {
    final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final font = pw.Font.ttf(fontData);
    final pdf = pw.Document();
    final invoice = _invoice!;
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: font),
      build: (context) => [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text('هیرکان پلاست | فاکتور فروش', style: pw.TextStyle(font: font, fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('شماره فاکتور: ${invoice['invoice_number']}'),
              pw.Text('تاریخ: ${invoice['date']}'),
              pw.Text('مشتری: ${(invoice['customer_name'] as String?)?.isNotEmpty == true ? invoice['customer_name'] : 'مشتری آزاد'}'),
              if ((invoice['customer_phone'] as String?)?.isNotEmpty == true) pw.Text('تلفن: ${invoice['customer_phone']}'),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headers: ['مبلغ کل', 'قیمت واحد', 'تعداد', 'کالا'],
                data: _items.map((item) => [
                  NumberFormatHelper.integer((item['line_total'] as num).toDouble()),
                  NumberFormatHelper.integer((item['unit_price'] as num).toDouble()),
                  '${NumberFormatHelper.quantity((item['quantity'] as num).toDouble())} ${item['unit']}',
                  '${item['product_name']}',
                ]).toList(),
                headerStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
                cellStyle: pw.TextStyle(font: font),
                cellAlignment: pw.Alignment.centerRight,
                headerAlignment: pw.Alignment.centerRight,
              ),
              pw.SizedBox(height: 16),
              pw.Text('جمع کالاها: ${NumberFormatHelper.integer((invoice['subtotal'] as num).toDouble())} ریال'),
              pw.Text('تخفیف: ${NumberFormatHelper.integer((invoice['discount'] as num).toDouble())} ریال'),
              pw.Text('مبلغ نهایی: ${NumberFormatHelper.integer((invoice['total'] as num).toDouble())} ریال',
                style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              if ((invoice['notes'] as String?)?.isNotEmpty == true) ...[
                pw.SizedBox(height: 10), pw.Text('توضیحات: ${invoice['notes']}'),
              ],
            ],
          ),
        ),
      ],
    ));
    return pdf.save();
  }
  Future<void> _sharePdf() async {
    setState(() => _working = true);
    try {
      final bytes = await _buildPdf();
      await Printing.sharePdf(bytes: bytes, filename: '${_invoice!['invoice_number']}.pdf');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ساخت یا اشتراک PDF ناموفق بود: $error')));
    } finally { if (mounted) setState(() => _working = false); }
  }
  Future<void> _printPdf() async {
    setState(() => _working = true);
    try {
      final bytes = await _buildPdf();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('چاپ فاکتور ناموفق بود: $error')));
    } finally { if (mounted) setState(() => _working = false); }
  }
  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    return Scaffold(
      appBar: AppBar(title: const Text('جزئیات فاکتور')),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : invoice == null ? const Center(child: Text('فاکتور پیدا نشد'))
        : ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${invoice['invoice_number']}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('تاریخ: ${invoice['date']}'),
                Text('مشتری: ${(invoice['customer_name'] as String?)?.isNotEmpty == true ? invoice['customer_name'] : 'مشتری آزاد'}'),
                if ((invoice['customer_phone'] as String?)?.isNotEmpty == true) Text('تماس: ${invoice['customer_phone']}'),
              ],
            ))),
            const SizedBox(height: 8),
            ..._items.map((item) => Card(child: ListTile(
              title: Text('${item['product_name']}'),
              subtitle: Text('${item['quantity']} ${item['unit']} × ${NumberFormatHelper.integer((item['unit_price'] as num).toDouble())} ریال'),
              trailing: Text('${NumberFormatHelper.integer((item['line_total'] as num).toDouble())} ریال'),
            ))),
            const SizedBox(height: 8),
            _SummaryRow(label: 'جمع کالاها', value: (invoice['subtotal'] as num).toDouble()),
            _SummaryRow(label: 'تخفیف', value: (invoice['discount'] as num).toDouble()),
            const Divider(),
            _SummaryRow(label: 'مبلغ نهایی', value: (invoice['total'] as num).toDouble(), bold: true),
            if ((invoice['notes'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 12), Text('توضیحات: ${invoice['notes']}'),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: _working ? null : _sharePdf, icon: const Icon(Icons.share), label: const Text('اشتراک‌گذاری PDF')),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _working ? null : _printPdf, icon: const Icon(Icons.print), label: const Text('چاپ فاکتور')),
            if (_working) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
          ],
        ),
    );
  }
}

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final grouped = digits.replaceAllMapped(RegExp(r'([0-9])(?=([0-9]{3})+$)'), (m) => '${m[1]},');
    return TextEditingValue(text: grouped, selection: TextSelection.collapsed(offset: grouped.length));
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  const _SummaryRow({required this.label, required this.value, this.bold = false});
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: style)),
        Text('${NumberFormatHelper.integer(value)} ریال', style: style),
      ]),
    );
  }
}
