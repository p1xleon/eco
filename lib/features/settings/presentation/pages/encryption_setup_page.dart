import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/crypto/crypto_providers.dart';
import '../../../../core/crypto/encryption_migration.dart';
import '../../../../core/database/isar_service.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../core/sync/sync_state.dart';

/// Sets up, or shows, the key everything on the server is encrypted with.
///
/// The recovery phrase is the key itself rather than a passphrase that unlocks
/// one, so there is no reset path and nothing to ask a server for. That is the
/// whole bargain of end-to-end encryption, and this screen says so plainly
/// instead of burying it.
class EncryptionSetupPage extends ConsumerStatefulWidget {
  const EncryptionSetupPage({super.key});

  @override
  ConsumerState<EncryptionSetupPage> createState() =>
      _EncryptionSetupPageState();
}

class _EncryptionSetupPageState extends ConsumerState<EncryptionSetupPage> {
  final _phraseController = TextEditingController();

  String? _newPhrase;
  bool _acknowledged = false;
  bool _isWorking = false;
  String? _error;

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _isWorking = true;
      _error = null;
    });

    try {
      final phrase = await ref.read(dataKeyProvider.notifier).create();
      if (!mounted) return;

      setState(() => _newPhrase = phrase);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _restoreFromPhrase() async {
    setState(() {
      _isWorking = true;
      _error = null;
    });

    try {
      await ref
          .read(dataKeyProvider.notifier)
          .restoreFromPhrase(_phraseController.text);
      if (!mounted) return;

      Navigator.pop(context);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  /// Queues everything the server holds in plaintext for re-upload, then syncs.
  ///
  /// Done here rather than at key creation so it only runs once the user has
  /// confirmed they wrote the phrase down — until that point, encrypting the
  /// server copy would be locking data behind a key nobody has recorded.
  Future<void> _finishSetup() async {
    setState(() {
      _isWorking = true;
      _error = null;
    });

    try {
      final queued = await EncryptionMigration.queueAll(IsarService.isar);
      if (!mounted) return;

      await syncNow(ref);
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              queued == 0
                  ? 'Encryption is on.'
                  : 'Encryption is on. Re-uploading $queued records.',
            ),
          ),
        );

      Navigator.pop(context);
    } catch (error) {
      // The records stay queued either way, so the next sync picks them up.
      if (mounted) setState(() => _error = describeSyncError(error));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  void _copy(String phrase) {
    Clipboard.setData(ClipboardData(text: phrase));

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Copied. Move it somewhere you will still have it if '
              'this phone is lost.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final existingPhrase = ref.watch(dataKeyProvider.notifier).recoveryPhrase;

    return Scaffold(
      appBar: AppBar(title: const Text('Encryption')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_newPhrase != null)
            _PhraseCard(
              phrase: _newPhrase!,
              title: 'Write this down now',
              body: 'This phrase is your key. Without it, a backup or a new '
                  'phone cannot read your data — and nobody can reset it for '
                  'you.',
              onCopy: () => _copy(_newPhrase!),
            )
          else if (existingPhrase != null)
            _PhraseCard(
              phrase: existingPhrase,
              title: 'Your recovery phrase',
              body: 'Encryption is on. Keep this phrase somewhere safe and '
                  'away from this phone.',
              onCopy: () => _copy(existingPhrase),
            )
          else
            ..._setupChildren(),
          if (_newPhrase != null) ...[
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _acknowledged,
              onChanged: (value) =>
                  setState(() => _acknowledged = value ?? false),
              title: const Text('I have written down my recovery phrase'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _acknowledged && !_isWorking ? _finishSetup : null,
              child: const Text('Done'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _setupChildren() {
    return [
      Text(
        'Turn on encryption',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Your transactions are encrypted on this device before they are '
        'uploaded, so the server only ever stores unreadable text. Dates and '
        'categories stay readable so syncing keeps working.',
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _isWorking ? null : _generate,
        child: const Text('Generate my key'),
      ),
      const SizedBox(height: 28),
      Text(
        'Already have a phrase?',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      const Text(
        'Enter the phrase from your other device to read data that is already '
        'encrypted.',
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _phraseController,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Recovery phrase',
          hintText: 'XXXX-XXXX-XXXX-…',
        ),
        maxLines: 3,
        autocorrect: false,
        enableSuggestions: false,
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: _isWorking ? null : _restoreFromPhrase,
        child: const Text('Use this phrase'),
      ),
    ];
  }
}

class _PhraseCard extends StatelessWidget {
  const _PhraseCard({
    required this.phrase,
    required this.title,
    required this.body,
    required this.onCopy,
  });

  final String phrase;
  final String title;
  final String body;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.50),
                borderRadius: BorderRadius.circular(18),
              ),
              child: SelectableText(
                phrase,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy'),
            ),
          ],
        ),
      ),
    );
  }
}
