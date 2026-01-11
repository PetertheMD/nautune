import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/sync_status_provider.dart';

/// A compact sync status indicator for app bars
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncStatusProvider>(
      builder: (context, syncStatus, _) {
        return _buildIndicator(context, syncStatus);
      },
    );
  }

  Widget _buildIndicator(BuildContext context, SyncStatusProvider syncStatus) {
    final theme = Theme.of(context);

    // Don't show anything if idle and no pending actions
    if (syncStatus.status == SyncStatus.idle && !syncStatus.hasPendingActions) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: _getTooltip(syncStatus),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _buildStatusWidget(context, syncStatus, theme),
      ),
    );
  }

  Widget _buildStatusWidget(BuildContext context, SyncStatusProvider syncStatus, ThemeData theme) {
    switch (syncStatus.status) {
      case SyncStatus.syncing:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        );

      case SyncStatus.pending:
        return Badge(
          label: Text(
            syncStatus.badgeText,
            style: const TextStyle(fontSize: 10),
          ),
          child: Icon(
            Icons.cloud_upload_outlined,
            size: 20,
            color: theme.colorScheme.tertiary,
          ),
        );

      case SyncStatus.error:
        return GestureDetector(
          onTap: () => _showErrorDialog(context, syncStatus),
          child: Icon(
            Icons.cloud_off,
            size: 20,
            color: theme.colorScheme.error,
          ),
        );

      case SyncStatus.offline:
        return Icon(
          Icons.cloud_off,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        );

      case SyncStatus.idle:
        // Show last sync time if available
        if (syncStatus.lastSyncTime != null) {
          return Icon(
            Icons.cloud_done,
            size: 20,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          );
        }
        return const SizedBox.shrink();
    }
  }

  String _getTooltip(SyncStatusProvider syncStatus) {
    final timeAgo = syncStatus.timeSinceLastSync;
    final base = syncStatus.statusDescription;

    if (timeAgo != null && syncStatus.status == SyncStatus.idle) {
      return '$base\nLast sync: $timeAgo';
    }

    if (syncStatus.status == SyncStatus.error && syncStatus.lastError != null) {
      return '$base\n${syncStatus.lastError}';
    }

    return base;
  }

  void _showErrorDialog(BuildContext context, SyncStatusProvider syncStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Error'),
        content: Text(syncStatus.lastError ?? 'An unknown error occurred during sync.'),
        actions: [
          TextButton(
            onPressed: () {
              syncStatus.clearError();
              Navigator.pop(context);
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
}

/// A more detailed sync status widget for settings or status screens
class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<SyncStatusProvider>(
      builder: (context, syncStatus, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _getStatusIcon(syncStatus, theme),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sync Status',
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            syncStatus.statusDescription,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _getStatusColor(syncStatus, theme),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (syncStatus.hasPendingActions) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: null,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${syncStatus.pendingActionsCount} actions waiting to sync',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (syncStatus.lastSyncTime != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last sync: ${syncStatus.timeSinceLastSync ?? "Unknown"}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _getStatusIcon(SyncStatusProvider syncStatus, ThemeData theme) {
    switch (syncStatus.status) {
      case SyncStatus.syncing:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        );
      case SyncStatus.pending:
        return Icon(Icons.cloud_upload, color: theme.colorScheme.tertiary);
      case SyncStatus.error:
        return Icon(Icons.error, color: theme.colorScheme.error);
      case SyncStatus.offline:
        return Icon(Icons.cloud_off, color: theme.colorScheme.onSurfaceVariant);
      case SyncStatus.idle:
        return Icon(Icons.cloud_done, color: theme.colorScheme.primary);
    }
  }

  Color _getStatusColor(SyncStatusProvider syncStatus, ThemeData theme) {
    switch (syncStatus.status) {
      case SyncStatus.syncing:
        return theme.colorScheme.primary;
      case SyncStatus.pending:
        return theme.colorScheme.tertiary;
      case SyncStatus.error:
        return theme.colorScheme.error;
      case SyncStatus.offline:
        return theme.colorScheme.onSurfaceVariant;
      case SyncStatus.idle:
        return theme.colorScheme.primary;
    }
  }
}
