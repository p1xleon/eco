import 'package:flutter/material.dart';

import '../../../settings/data/models/transaction_preset_model.dart';

class TransactionFormSection extends StatelessWidget {
  final String? title;
  final Widget child;

  const TransactionFormSection({super.key, this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class TransactionPresetField extends StatelessWidget {
  final String label;
  final String hintText;
  final String emptyStateText;
  final TextEditingController controller;
  final List<TransactionPresetModel> presets;

  const TransactionPresetField({
    super.key,
    required this.label,
    required this.hintText,
    required this.emptyStateText,
    required this.controller,
    required this.presets,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label, hintText: hintText),
        ),
        const SizedBox(height: 10),
        if (presets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.8),
              ),
            ),
            child: Text(
              emptyStateText,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else ...[
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, text, _) {
              final value = text.text.trim().toLowerCase();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Presets',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${presets.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets
                        .map((preset) {
                          final isSelected =
                              preset.value.toLowerCase() == value;

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => controller.text = preset.value,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? scheme.primaryContainer
                                    : scheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? scheme.primary
                                      : scheme.outlineVariant.withValues(
                                          alpha: 0.8,
                                        ),
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: scheme.primary.withValues(
                                            alpha: 0.10,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.add_circle_outline_rounded,
                                    size: 16,
                                    color: isSelected
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      preset.value,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? scheme.onPrimaryContainer
                                                : scheme.onSurface,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
