import 'package:flutter/material.dart';

import '../app_state.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.appState});

  final NautuneAppState appState;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final session = appState.session;
        final libraries = appState.libraries;
        final isLoading = appState.isLoadingLibraries;
        final error = appState.librariesError;
        final selectedId = appState.selectedLibraryId;
        final theme = Theme.of(context);

        Widget body;

        if (isLoading && (libraries == null || libraries.isEmpty)) {
          body = const Center(child: CircularProgressIndicator());
        } else if (error != null) {
          body = _ErrorState(
            message: 'Could not reach Jellyfin.\n${error.toString()}',
            onRetry: () => appState.refreshLibraries(),
          );
        } else if (libraries == null || libraries.isEmpty) {
          body = _EmptyState(
            onRefresh: () => appState.refreshLibraries(),
          );
        } else {
          body = RefreshIndicator(
            onRefresh: () => appState.refreshLibraries(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: libraries.length + 1,
              separatorBuilder: (_, index) => index == 0
                  ? const SizedBox(height: 16)
                  : const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _Header(
                    username: session?.username ?? 'Explorer',
                    serverUrl: session?.serverUrl ?? '',
                    selectedLibraryName: session?.selectedLibraryName,
                  );
                }
                final library = libraries[index - 1];
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: theme.colorScheme.surface.withOpacity(0.6),
                  ),
                  child: RadioListTile<String>(
                    value: library.id,
                    groupValue: selectedId,
                    onChanged: (_) async {
                      await appState.selectLibrary(library);
                    },
                    title: Text(library.name),
                    subtitle: library.collectionType != null
                        ? Text(
                            library.collectionType!,
                            style: theme.textTheme.bodySmall,
                          )
                        : null,
                    secondary: const Icon(Icons.library_music_outlined),
                    controlAffinity: ListTileControlAffinity.trailing,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                );
              },
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nautune'),
            actions: [
              IconButton(
                onPressed: () => appState.logout(),
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
              ),
            ],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: body,
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.username,
    required this.serverUrl,
    this.selectedLibraryName,
  });

  final String username;
  final String serverUrl;
  final String? selectedLibraryName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ahoy, $username!',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Connected to $serverUrl',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Select your Jellyfin audio library',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        if (selectedLibraryName != null)
          Text(
            'Currently linked: $selectedLibraryName',
            style: theme.textTheme.bodySmall,
          )
        else
          Text(
            'Pick one to sync Nautune with your tunes.',
            style: theme.textTheme.bodySmall,
          ),
        Text(
          'Only audio-compatible libraries are shown.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 48),
          const SizedBox(height: 12),
          Text(
            'No audio libraries found.',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add a music, audiobooks, or music videos library in Jellyfin and refresh.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () {
              onRefresh();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Signal lost',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                onRetry();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
