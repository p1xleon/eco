import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/privacy/transaction_visibility.dart';
import '../../../../core/utils/money.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../data/models/recurring_transaction_model.dart';
import '../providers/recurring_transaction_provider.dart';

/// Pick any transactions and point them at [template]. Pops with how many
/// were linked.
class LinkTransactionsPage extends ConsumerStatefulWidget {
  final RecurringTransactionModel template;

  const LinkTransactionsPage({super.key, required this.template});

  @override
  ConsumerState<LinkTransactionsPage> createState() =>
      _LinkTransactionsPageState();
}

class _LinkTransactionsPageState extends ConsumerState<LinkTransactionsPage> {
  late final _search = TextEditingController(text: widget.template.title);
  final _selected = <int>{};
  final _dateFormat = DateFormat('dd MMM yyyy');
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    setState(() => _saving = true);
    final count = await ref
        .read(recurringRecoveryServiceProvider)
        .relink(_selected.toList(), widget.template);
    if (mounted) Navigator.pop(context, count);
  }

  @override
  Widget build(BuildContext context) {
    final visibility = ref.watch(transactionVisibilityProvider);
    final templates = ref.watch(recurringTransactionsProvider).valueOrNull;
    final templateTitles = {
      for (final t in templates ?? const <RecurringTransactionModel>[])
        t.id: t.title,
    };
    final query = _search.text.trim().toLowerCase();
    // Matched on what is shown, so masked mode cannot be probed by searching.
    final shown = [
      for (final tx
          in ref.watch(visibleTransactionsProvider).valueOrNull ??
              <TransactionModel>[])
        if (query.isEmpty ||
            visibility.displayTitle(tx).toLowerCase().contains(query))
          tx,
    ]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text('Link to "${widget.template.title}"'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              final ids = shown.map((tx) => tx.id);
              _selected.containsAll(ids)
                  ? _selected.removeAll(ids)
                  : _selected.addAll(ids);
            }),
            child: const Text('All shown'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search transactions',
              ),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? const Center(child: Text('No transactions match.'))
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, index) {
                      final tx = shown[index];
                      final linkedId = tx.recurringTemplateId;
                      final linked = linkedId == null
                          ? 'not linked'
                          : linkedId == widget.template.id
                          ? 'already linked here'
                          : templateTitles.containsKey(linkedId)
                          ? 'linked to #$linkedId'
                          : 'linked to #$linkedId (deleted)';

                      return CheckboxListTile(
                        value: _selected.contains(tx.id),
                        onChanged: (v) => setState(
                          () => v == true
                              ? _selected.add(tx.id)
                              : _selected.remove(tx.id),
                        ),
                        title: Text(visibility.displayTitle(tx)),
                        subtitle: Text(
                          '${_dateFormat.format(tx.date)} · '
                          '${visibility.displayAmount(formatMoney(tx.amount))}'
                          ' · $linked',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _selected.isEmpty || _saving ? null : _link,
            child: Text('Link ${_selected.length} selected'),
          ),
        ),
      ),
    );
  }
}
