import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../models/client.dart';
import '../../models/clinic.dart';
import '../../services/api_service.dart';
import '../../services/app_feedback.dart';
import '../../services/pro_service.dart';
import '../../widgets/document_tile.dart' show openDocument;
import '../clinic/clinic_sheets.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  INVOICES & QUOTES — bill a client in under a minute.
///
///  The list shows what is unpaid first. "New" opens the editor: client,
///  invoice or quote, line items (qty × rate), GST at the standard Indian
///  rates, a due date. "Create" files the PDF under the client, adds the
///  invoice to their dues, and — when Razorpay is set up on the server —
///  attaches a payment link that marks the invoice paid by itself.
/// ─────────────────────────────────────────────────────────────────────────
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  String _kind = 'invoice';
  List<Invoice>? _items;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ProService.instance.invoices(kind: _kind);
    if (!mounted) return;
    setState(() {
      _items = r ?? _items;
      _failed = r == null && _items == null;
    });
  }

  Future<void> _new() async {
    final ok = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => InvoiceEditorScreen(kind: _kind)));
    if (ok == true) _load();
  }

  Future<void> _open(Invoice i) async {
    final id = i.documentId;
    if (id == null) return;
    try {
      final docs = await ApiService.fetchDocuments();
      final d = docs.where((x) => x.id == id).firstOrNull;
      if (d != null && mounted) openDocument(context, d);
    } catch (_) {
      AppFeedback.toast("Couldn't open the PDF.");
    }
  }

  void _menu(Invoice i) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Neon.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (i.documentId != null)
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('Open PDF'),
              onTap: () {
                Navigator.pop(ctx);
                _open(i);
              },
            ),
          if (i.paymentUrl.isNotEmpty && !i.isPaid)
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Copy payment link'),
              subtitle: Text(i.paymentUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Clipboard.setData(ClipboardData(text: i.paymentUrl));
                Navigator.pop(ctx);
                AppFeedback.toast('Payment link copied — paste it in WhatsApp.');
              },
            ),
          if (!i.isQuote && !i.isPaid)
            ListTile(
              leading: Icon(Icons.check_circle_rounded, color: Neon.success),
              title: const Text('Mark as paid (cash / bank)'),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await ProService.instance.markInvoicePaid(i.id);
                AppFeedback.toast(ok ? '${i.number} marked paid.' : "Couldn't update. Check your connection.");
                _load();
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: appleAppBar(context, 'Invoices & quotes'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Neon.violet,
        foregroundColor: Colors.white,
        onPressed: _new,
        icon: const Icon(Icons.add_rounded),
        label: Text(_kind == 'quote' ? 'New quote' : 'New invoice'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'invoice', label: Text('Invoices')),
              ButtonSegment(value: 'quote', label: Text('Quotes')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) {
              setState(() {
                _kind = s.first;
                _items = null;
              });
              _load();
            },
          ),
        ),
        Expanded(
          child: _failed
              ? NeonErrorState(
                  message: "Couldn't load invoices.",
                  onRetry: () {
                    setState(() => _failed = false);
                    _load();
                  })
              : items == null
                  ? const Center(child: NeonLoader())
                  : items.isEmpty
                      ? NeonEmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: _kind == 'quote' ? 'No quotes yet' : 'No invoices yet',
                          body: 'Create one in a few taps — it\'s filed under the client as a PDF.',
                        )
                      : RefreshIndicator(
                          color: Neon.violet,
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                            children: [
                              GroupedCard(dividerInset: 16, children: [
                                for (final i in [
                                  ...items.where((x) => !x.isPaid),
                                  ...items.where((x) => x.isPaid),
                                ])
                                  AppleRow(
                                    title: '${i.number} · ${i.clientName.isEmpty ? '—' : i.clientName}',
                                    subtitle: [
                                      if (i.gstRate > 0) 'incl. GST ${i.gstRate.toStringAsFixed(0)}%',
                                      i.isQuote ? 'Quote' : (i.isPaid ? 'Paid' : 'Unpaid'),
                                    ].join(' · '),
                                    trailing: Text(rupees(i.total),
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: i.isPaid || i.isQuote ? Neon.textHi : Neon.warning)),
                                    onTap: () => _menu(i),
                                  ),
                              ]),
                            ],
                          ),
                        ),
        ),
      ]),
    );
  }
}

/* ====================================================================== */
/* Editor                                                                  */
/* ====================================================================== */

class InvoiceEditorScreen extends StatefulWidget {
  const InvoiceEditorScreen({super.key, this.kind = 'invoice', this.clientId, this.clientName, this.presetLine});
  final String kind;
  final int? clientId;
  final String? clientName;

  /// A first line already written ("Professional fee — OS 112/2026").
  final String? presetLine;

  @override
  State<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

class _LineCtl {
  final desc = TextEditingController();
  final qty = TextEditingController(text: '1');
  final rate = TextEditingController();
  void dispose() {
    desc.dispose();
    qty.dispose();
    rate.dispose();
  }

  InvoiceLine get line => InvoiceLine(
        description: desc.text,
        qty: double.tryParse(qty.text.trim()) ?? 0,
        rate: double.tryParse(rate.text.replaceAll(',', '').trim()) ?? 0,
      );
}

class _InvoiceEditorScreenState extends State<InvoiceEditorScreen> {
  late String _kind = widget.kind;
  late int? _clientId = widget.clientId;
  late String? _clientName = widget.clientName;
  late final List<_LineCtl> _lines = [_LineCtl()..desc.text = widget.presetLine ?? ''];
  double _gst = 0;
  int? _dueDays = 15;
  final _notes = TextEditingController();
  bool _busy = false;

  static const _gstRates = [0.0, 5.0, 12.0, 18.0, 28.0];

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  double get _subtotal => _lines.fold(0, (s, l) => s + l.line.amount);
  double get _gstAmt => (_subtotal * _gst / 100 * 100).round() / 100;
  double get _total => _subtotal + _gstAmt;

  Future<void> _save() async {
    final id = _clientId;
    if (id == null) {
      AppFeedback.toast('Choose the client first.');
      return;
    }
    final items = _lines.map((l) => l.line).where((l) => l.description.trim().isNotEmpty && l.qty > 0).toList();
    if (items.isEmpty) {
      AppFeedback.toast('Add at least one item with a quantity.');
      return;
    }
    setState(() => _busy = true);
    final r = await ProService.instance.createInvoice(
      clientId: id,
      kind: _kind,
      items: items,
      gstRate: _gst,
      notes: _notes.text.trim(),
      dueAt: _dueDays == null ? null : DateTime.now().add(Duration(days: _dueDays!)),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == null) {
      AppFeedback.toast("Couldn't create it. Check your connection.");
      return;
    }
    HapticFeedback.lightImpact();
    final inv = r.invoice;
    if (inv.paymentUrl.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: inv.paymentUrl));
      if (!mounted) return;
      AppFeedback.toast('${inv.number} created. Payment link copied — paste it to $_clientName.');
    } else {
      AppFeedback.toast(r.paymentError != null && !inv.isQuote
          ? '${inv.number} created. (${r.paymentError})'
          : '${inv.number} created and filed under $_clientName.');
    }
    final nav = Navigator.of(context);
    nav.pop(true);
    final doc = r.document;
    if (doc != null) openDocument(nav.context, doc);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: appleAppBar(context, _kind == 'quote' ? 'New quote' : 'New invoice'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'invoice', label: Text('Invoice'), icon: Icon(Icons.receipt_long_rounded)),
              ButtonSegment(value: 'quote', label: Text('Quote'), icon: Icon(Icons.request_quote_rounded)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 14),
          GroupedCard(children: [
            AppleRow(
              leading: IconTile(Icons.business_rounded, Neon.accentF),
              title: _clientName ?? 'Choose client',
              titleColor: _clientName == null ? Neon.violet : null,
              trailing: Icon(Icons.chevron_right_rounded, color: Neon.textDim),
              onTap: () async {
                final Client? c = await pickPatient(context);
                if (c != null) {
                  setState(() {
                    _clientId = c.id;
                    _clientName = c.name;
                  });
                }
              },
            ),
          ]),
          const SizedBox(height: 18),
          GroupLabel('Items · ${_lines.length}'),
          for (var i = 0; i < _lines.length; i++) _lineCard(i),
          TextButton.icon(
            onPressed: () => setState(() => _lines.add(_LineCtl())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add item'),
          ),
          const SizedBox(height: 10),
          Text('GST', style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final g in _gstRates)
              ChoiceChip(
                label: Text(g == 0 ? 'None' : '${g.toStringAsFixed(0)}%'),
                selected: _gst == g,
                showCheckmark: false,
                selectedColor: Neon.violet.withValues(alpha: 0.15),
                onSelected: (_) => setState(() => _gst = g),
              ),
          ]),
          const SizedBox(height: 14),
          Text(_kind == 'quote' ? 'Valid for' : 'Payment due in',
              style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final d in const [7, 15, 30, 45])
              ChoiceChip(
                label: Text('$d days'),
                selected: _dueDays == d,
                showCheckmark: false,
                selectedColor: Neon.violet.withValues(alpha: 0.15),
                onSelected: (_) => setState(() => _dueDays = d),
              ),
            ChoiceChip(
              label: const Text('No date'),
              selected: _dueDays == null,
              showCheckmark: false,
              selectedColor: Neon.violet.withValues(alpha: 0.15),
              onSelected: (_) => setState(() => _dueDays = null),
            ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _notes,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'e.g. Bank details, terms'),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Neon.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Neon.line),
            ),
            child: Column(children: [
              _totalRow('Subtotal', rupees(_subtotal)),
              if (_gst > 0) _totalRow('GST ${_gst.toStringAsFixed(0)}%', rupees(_gstAmt)),
              const Divider(height: 18),
              _totalRow('Total', rupees(_total), bold: true),
            ]),
          ),
          const SizedBox(height: 18),
          ApplePrimaryButton(
            label: _busy ? 'Creating…' : (_kind == 'quote' ? 'Create quote' : 'Create invoice'),
            icon: Icons.picture_as_pdf_rounded,
            onPressed: _busy ? null : _save,
          ),
          if (_kind == 'invoice') ...[
            const SizedBox(height: 8),
            Text('A payment link is attached when online payments are set up.',
                textAlign: TextAlign.center, style: TextStyle(color: Neon.textDim, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _totalRow(String l, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(
              child: Text(l,
                  style: TextStyle(
                      color: bold ? Neon.textHi : Neon.textLo, fontSize: bold ? 16 : 14,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
          Text(v,
              style: TextStyle(
                  color: Neon.textHi, fontSize: bold ? 18 : 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );

  Widget _lineCard(int i) {
    final l = _lines[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 4, 6, 10),
      decoration: BoxDecoration(
        color: Neon.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Neon.line),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: l.desc,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: '${i + 1}. Description', border: InputBorder.none),
            ),
          ),
          if (_lines.length > 1)
            IconButton(
              tooltip: 'Remove',
              icon: Icon(Icons.delete_outline_rounded, color: Neon.textDim),
              onPressed: () => setState(() => _lines.removeAt(i).dispose()),
            ),
        ]),
        // Room for the Qty / Rate labels, which float above their boxes.
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(
            width: 80,
            child: TextField(
              controller: l.qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Qty', isDense: true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: l.rate,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Rate', prefixText: '₹ ', isDense: true),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(rupees(l.line.amount),
                textAlign: TextAlign.right,
                style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w700)),
          ),
        ]),
      ]),
    );
  }
}
