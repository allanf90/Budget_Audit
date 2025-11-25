// lib/features/home/widgets/side_panel.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../home_viewmodel.dart';

class SidePanel extends StatelessWidget {
  const SidePanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Participants Section
          _buildParticipantsSection(viewModel),
          const SizedBox(height: AppTheme.spacingXl),

          // Template Actions Section
          _buildTemplateActionsSection(),
          const SizedBox(height: AppTheme.spacingXl),

          // Template History Section
          _buildTemplateHistorySection(viewModel),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection(HomeViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Participants',
          style: AppTheme.h4,
        ),
        const SizedBox(height: AppTheme.spacingMd),
        ...viewModel.participants.map((participant) {
          final initials = (participant.nickname ?? participant.firstName)
              .substring(0, 2)
              .toUpperCase();
          final isCurrentUser =
              participant.participantId == viewModel.currentParticipantId;

          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isCurrentUser
                      ? AppTheme.primaryPink
                      : AppTheme.primaryBlue,
                  radius: 20,
                  child: Text(
                    initials,
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participant.nickname ?? participant.firstName,
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        participant.email,
                        style: AppTheme.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isCurrentUser)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingXs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPink.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                    ),
                    child: Text(
                      'You',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.primaryPink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: AppTheme.spacingSm),
        OutlinedButton.icon(
          onPressed: () {
            // TODO: Add participant functionality
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add participant'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryBlue,
            side: BorderSide(color: AppTheme.primaryBlue, width: 1),
            minimumSize: const Size(double.infinity, 40),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildActionButton(
          label: 'Download your current template',
          buttonLabel: 'Download Template',
          onPressed: () {
            // TODO: Implement download template
          },
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _buildActionButton(
          label: 'Download your current budget',
          buttonLabel: 'Download Budget',
          onPressed: () {
            // TODO: Implement download budget
          },
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _buildActionButton(
          label: 'Open your current template',
          buttonLabel: 'Open Template',
          onPressed: () {
            // TODO: Implement open template
          },
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _buildActionButton(
          label: 'Open your current budget',
          buttonLabel: 'Open Budget',
          onPressed: () {
            // TODO: Implement open budget
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacingXs),
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.surface,
            foregroundColor: AppTheme.textPrimary,
            elevation: 0,
            side: BorderSide(color: AppTheme.border, width: 1),
            minimumSize: const Size(double.infinity, 40),
          ),
          child: Text(buttonLabel),
        ),
      ],
    );
  }

  Widget _buildTemplateHistorySection(HomeViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Template History',
              style: AppTheme.h4,
            ),
            OutlinedButton(
              onPressed: () {
                // TODO: Adopt template functionality
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
                side: BorderSide(color: AppTheme.primaryBlue, width: 1),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSm,
                  vertical: AppTheme.spacingXs,
                ),
              ),
              child: const Text('Adopt Template'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        if (viewModel.templateHistory.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Text(
                'No templates yet',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          )
        else
          ...viewModel.templateHistory.map((template) {
            return _buildTemplateCard(viewModel, template);
          }).toList(),
      ],
    );
  }

  Widget _buildTemplateCard(
    HomeViewModel viewModel,
    template,
  ) {
    final dateStr = DateFormat('dd/MM/yy').format(template.dateCreated);
    // Mock budget amount - replace with actual data
    final budgetAmount = '\$65012';

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border, width: 1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date Created: $dateStr',
                      style: AppTheme.bodySmall,
                    ),
                    Text(
                      'Budgeted: $budgetAmount',
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _showPreview(template),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: 'Preview',
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: Implement minimize
                    },
                    icon: const Icon(Icons.remove, size: 18),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: 'Minimize',
                  ),
                  IconButton(
                    onPressed: () =>
                        _confirmDeleteTemplate(viewModel, template),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppTheme.error,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXs),

          // Status indicator
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppTheme.spacingXs),
              Text(
                'Current',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPreview(template) {
    // Get the context from the widget tree
    // This is a simplified version - you'll need to pass context properly
    // showDialog(
    //   context: context,
    //   builder: (context) => AlertDialog(
    //     title: const Text('Template Preview'),
    //     content: const Text('Preview goes here'),
    //     actions: [
    //       TextButton(
    //         onPressed: () => Navigator.pop(context),
    //         child: const Text('Close'),
    //       ),
    //     ],
    //   ),
    // );
  }

  void _confirmDeleteTemplate(HomeViewModel viewModel, template) {
    // Similar to above - needs context
    // showDialog to confirm deletion
  }
}
