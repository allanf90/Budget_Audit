import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/preset_models.dart';
import 'package:intl/intl.dart';

class PresetCard extends StatelessWidget {
  final BudgetPreset preset;
  final VoidCallback onAdopt;

  const PresetCard({
    Key? key,
    required this.preset,
    required this.onAdopt,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: context.colors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: AppTheme.h3,
                    ),
                    const SizedBox(height: AppTheme.spacingXs),
                    Text(
                      preset.description,
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onAdopt,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLg,
                    vertical: AppTheme.spacingSm,
                  ),
                ),
                child: const Text('Adopt'),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingMd),

          // Divider
          Container(
            height: 1,
            color: context.colors.border,
          ),

          const SizedBox(height: AppTheme.spacingMd),

          // Info chips
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingSm,
            children: [
              _buildInfoChip(
                context,
                icon: Icons.people_outline,
                label: preset.targetAudience,
              ),
              _buildInfoChip(
                context,
                icon: Icons.category_outlined,
                label: '${preset.totalCategories} categories',
              ),
              _buildInfoChip(
                context,
                icon: Icons.account_balance_wallet_outlined,
                label: '${preset.totalAccounts} accounts',
              ),
              _buildInfoChip(
                context,
                icon: Icons.calendar_today_outlined,
                label: preset.period,
              ),
              _buildInfoChip(
                context,
                icon: Icons.attach_money,
                label: currencyFormatter.format(preset.calculatedTotal),
                isHighlight: true,
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingMd),

          // Categories preview
          Text(
            'Categories Preview',
            style: AppTheme.bodySmall.copyWith(
              color: context.colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXs),
          Wrap(
            spacing: AppTheme.spacingXs,
            runSpacing: AppTheme.spacingXs,
            children: preset.categories.take(8).map<Widget>((category) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSm,
                  vertical: AppTheme.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: context.colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  category.name,
                  style: AppTheme.bodySmall.copyWith(
                    color: context.colors.primary,
                  ),
                ),
              );
            }).toList()
              ..add(
                preset.categories.length > 8
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSm,
                          vertical: AppTheme.spacingXs,
                        ),
                        child: Text(
                          '+${preset.categories.length - 8} more',
                          style: AppTheme.bodySmall.copyWith(
                            color: context.colors.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: isHighlight
            ? context.colors.secondary.withOpacity(0.1)
            : context.colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: isHighlight ? context.colors.secondary : context.colors.border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isHighlight
                ? context.colors.secondary
                : context.colors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: isHighlight
                  ? context.colors.secondary
                  : context.colors.textSecondary,
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
