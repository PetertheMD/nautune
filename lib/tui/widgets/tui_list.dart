import 'dart:math';

import 'package:flutter/material.dart';

import '../tui_metrics.dart';
import '../tui_theme.dart';

/// State for a TUI list with cursor and scroll management.
class TuiListState<T> extends ChangeNotifier {
  TuiListState({
    List<T>? items,
    this.visibleRows = 20,
    this.nameGetter,
  }) : _items = items ?? [];

  List<T> _items;
  int _cursorIndex = 0;
  int _scrollOffset = 0;
  int visibleRows;

  /// Optional function to get item name for letter jumping
  final String Function(T)? nameGetter;

  List<T> get items => _items;
  int get cursorIndex => _cursorIndex;
  int get scrollOffset => _scrollOffset;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  int get length => _items.length;

  T? get selectedItem =>
      _items.isNotEmpty && _cursorIndex < _items.length ? _items[_cursorIndex] : null;

  void setItems(List<T> newItems) {
    _items = newItems;
    // Clamp cursor to valid range
    if (_items.isEmpty) {
      _cursorIndex = 0;
      _scrollOffset = 0;
    } else {
      _cursorIndex = _cursorIndex.clamp(0, _items.length - 1);
      _adjustScroll();
    }
    notifyListeners();
  }

  void moveUp() {
    if (_items.isEmpty) return;
    _cursorIndex = max(0, _cursorIndex - 1);
    _adjustScroll();
    notifyListeners();
  }

  void moveDown() {
    if (_items.isEmpty) return;
    _cursorIndex = min(_items.length - 1, _cursorIndex + 1);
    _adjustScroll();
    notifyListeners();
  }

  void goToTop() {
    if (_items.isEmpty) return;
    _cursorIndex = 0;
    _scrollOffset = 0;
    notifyListeners();
  }

  void goToBottom() {
    if (_items.isEmpty) return;
    _cursorIndex = _items.length - 1;
    _adjustScroll();
    notifyListeners();
  }

  void pageUp() {
    if (_items.isEmpty) return;
    _cursorIndex = max(0, _cursorIndex - visibleRows);
    _adjustScroll();
    notifyListeners();
  }

  void pageDown() {
    if (_items.isEmpty) return;
    _cursorIndex = min(_items.length - 1, _cursorIndex + visibleRows);
    _adjustScroll();
    notifyListeners();
  }

  void selectIndex(int index) {
    if (_items.isEmpty || index < 0 || index >= _items.length) return;
    _cursorIndex = index;
    _adjustScroll();
    notifyListeners();
  }

  /// Jump to next letter group (A→B→C...) based on item names
  void jumpNextLetter() {
    if (_items.isEmpty || nameGetter == null) return;

    final currentName = nameGetter!(_items[_cursorIndex]);
    final currentLetter = currentName.isNotEmpty
        ? currentName[0].toUpperCase()
        : '';

    // Find next item with different starting letter
    for (int i = _cursorIndex + 1; i < _items.length; i++) {
      final itemName = nameGetter!(_items[i]);
      final itemLetter = itemName.isNotEmpty ? itemName[0].toUpperCase() : '';
      if (itemLetter != currentLetter && itemLetter.compareTo(currentLetter) > 0) {
        _cursorIndex = i;
        _adjustScroll();
        notifyListeners();
        return;
      }
    }

    // Wrap around to beginning
    for (int i = 0; i < _cursorIndex; i++) {
      final itemName = nameGetter!(_items[i]);
      final itemLetter = itemName.isNotEmpty ? itemName[0].toUpperCase() : '';
      if (itemLetter != currentLetter) {
        _cursorIndex = i;
        _adjustScroll();
        notifyListeners();
        return;
      }
    }
  }

  /// Jump to previous letter group based on item names
  void jumpPrevLetter() {
    if (_items.isEmpty || nameGetter == null) return;

    final currentName = nameGetter!(_items[_cursorIndex]);
    final currentLetter = currentName.isNotEmpty
        ? currentName[0].toUpperCase()
        : '';

    // Find previous item with different starting letter
    for (int i = _cursorIndex - 1; i >= 0; i--) {
      final itemName = nameGetter!(_items[i]);
      final itemLetter = itemName.isNotEmpty ? itemName[0].toUpperCase() : '';
      if (itemLetter != currentLetter && itemLetter.compareTo(currentLetter) < 0) {
        // Find the first item with this letter
        int firstWithLetter = i;
        while (firstWithLetter > 0) {
          final prevName = nameGetter!(_items[firstWithLetter - 1]);
          final prevLetter = prevName.isNotEmpty ? prevName[0].toUpperCase() : '';
          if (prevLetter == itemLetter) {
            firstWithLetter--;
          } else {
            break;
          }
        }
        _cursorIndex = firstWithLetter;
        _adjustScroll();
        notifyListeners();
        return;
      }
    }

    // Wrap around to end
    for (int i = _items.length - 1; i > _cursorIndex; i--) {
      final itemName = nameGetter!(_items[i]);
      final itemLetter = itemName.isNotEmpty ? itemName[0].toUpperCase() : '';
      if (itemLetter != currentLetter) {
        _cursorIndex = i;
        _adjustScroll();
        notifyListeners();
        return;
      }
    }
  }

  void _adjustScroll() {
    // Keep cursor visible within the viewport
    if (_cursorIndex < _scrollOffset) {
      _scrollOffset = _cursorIndex;
    } else if (_cursorIndex >= _scrollOffset + visibleRows) {
      _scrollOffset = _cursorIndex - visibleRows + 1;
    }
    // Clamp scroll offset
    final maxOffset = max(0, _items.length - visibleRows);
    _scrollOffset = _scrollOffset.clamp(0, maxOffset);
  }

  /// Returns the visible items based on current scroll position.
  List<T> get visibleItems {
    if (_items.isEmpty) return [];
    final end = min(_scrollOffset + visibleRows, _items.length);
    return _items.sublist(_scrollOffset, end);
  }

  /// Returns true if the given index is the cursor position.
  bool isCursor(int visibleIndex) {
    return (_scrollOffset + visibleIndex) == _cursorIndex;
  }

  /// Returns the actual list index for a visible index.
  int actualIndex(int visibleIndex) => _scrollOffset + visibleIndex;

  /// Returns true if the list is scrollable
  bool get isScrollable => _items.length > visibleRows;

  /// Returns scroll progress (0.0 to 1.0)
  double get scrollProgress {
    if (!isScrollable) return 0.0;
    final maxOffset = max(1, _items.length - visibleRows);
    return (_scrollOffset / maxOffset).clamp(0.0, 1.0);
  }
}

/// A scrollable list widget with vim-style cursor selection.
class TuiList<T> extends StatelessWidget {
  const TuiList({
    super.key,
    required this.state,
    required this.itemBuilder,
    this.emptyMessage = 'No items',
    this.playingIndex,
    this.showScrollbar = true,
  });

  final TuiListState<T> state;
  final Widget Function(BuildContext context, T item, int index, bool isSelected, bool isPlaying) itemBuilder;
  final String emptyMessage;
  final int? playingIndex;
  final bool showScrollbar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate visible rows based on available height
        // Subtract 1 to prevent overflow from rounding errors
        final availableHeight = constraints.maxHeight;
        final rowHeight = TuiMetrics.charHeight;
        final calculatedRows = max(1, (availableHeight / rowHeight).floor() - 1);

        // Update state with calculated visible rows
        if (state.visibleRows != calculatedRows && calculatedRows > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            state.visibleRows = calculatedRows;
            // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
            state.notifyListeners();
          });
        }

        return ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            if (state.isEmpty) {
              return Center(
                child: Text(emptyMessage, style: TuiTextStyles.dim),
              );
            }

            // Use calculated rows directly to prevent overflow on first render
            final effectiveVisibleRows = min(calculatedRows, state.length);
            final visibleItems = state.items.isEmpty
                ? <T>[]
                : state.items.sublist(
                    state.scrollOffset,
                    min(state.scrollOffset + effectiveVisibleRows, state.length),
                  );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRect(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < visibleItems.length; i++)
                          SizedBox(
                            height: rowHeight,
                            child: itemBuilder(
                              context,
                              visibleItems[i],
                              state.actualIndex(i),
                              state.isCursor(i),
                              playingIndex != null && state.actualIndex(i) == playingIndex,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Scrollbar
                if (showScrollbar && state.length > effectiveVisibleRows)
                  _TuiScrollbar(
                    itemCount: state.length,
                    visibleRows: effectiveVisibleRows,
                    scrollOffset: state.scrollOffset,
                    totalHeight: availableHeight,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Visual scrollbar for TUI lists
class _TuiScrollbar extends StatelessWidget {
  const _TuiScrollbar({
    required this.itemCount,
    required this.visibleRows,
    required this.scrollOffset,
    required this.totalHeight,
  });

  final int itemCount;
  final int visibleRows;
  final int scrollOffset;
  final double totalHeight;

  @override
  Widget build(BuildContext context) {
    final charHeight = TuiMetrics.charHeight;
    final totalLines = (totalHeight / charHeight).floor();

    if (totalLines <= 0 || itemCount <= visibleRows) {
      return const SizedBox.shrink();
    }

    // Calculate thumb size and position
    final thumbSize = max(1, (visibleRows * totalLines / itemCount).round());
    final maxOffset = max(1, itemCount - visibleRows);
    final thumbPos = ((scrollOffset / maxOffset) * (totalLines - thumbSize)).round();

    return SizedBox(
      width: TuiMetrics.charWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < totalLines && i < visibleRows; i++)
            SizedBox(
              height: charHeight,
              child: Text(
                i >= thumbPos && i < thumbPos + thumbSize
                    ? TuiChars.scrollThumb
                    : TuiChars.scrollTrack,
                style: TuiTextStyles.normal.copyWith(
                  color: i >= thumbPos && i < thumbPos + thumbSize
                      ? TuiColors.accent
                      : TuiColors.border,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A single list item row with selection styling.
class TuiListItem extends StatelessWidget {
  const TuiListItem({
    super.key,
    required this.text,
    this.isSelected = false,
    this.isPlaying = false,
    this.prefix,
    this.suffix,
    this.onTap,
    this.isTemporaryQueue = false,
  });

  final String text;
  final bool isSelected;
  final bool isPlaying;
  final String? prefix;
  final String? suffix;
  final VoidCallback? onTap;
  final bool isTemporaryQueue;

  @override
  Widget build(BuildContext context) {
    final TextStyle style;
    if (isSelected) {
      style = TuiTextStyles.selection;
    } else if (isPlaying) {
      style = TuiTextStyles.playing;
    } else {
      style = TuiTextStyles.normal;
    }

    String prefixText;
    if (isSelected) {
      prefixText = '${TuiChars.cursor} ';
    } else if (isPlaying) {
      prefixText = '${TuiChars.playing} ';
    } else if (isTemporaryQueue) {
      prefixText = '${TuiChars.tempQueueMarker} ';
    } else {
      prefixText = prefix ?? '  ';
    }

    final suffixText = suffix ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: isSelected ? TuiColors.selection : Colors.transparent,
        child: ClipRect(
          child: Row(
            children: [
              Text(prefixText, style: style),
              Expanded(
                child: Text(
                  text,
                  style: style,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (suffixText.isNotEmpty)
                Flexible(
                  flex: 0,
                  child: Text(' $suffixText', style: style.copyWith(color: TuiColors.dim), overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Album header item for track lists (non-selectable)
class TuiAlbumHeader extends StatelessWidget {
  const TuiAlbumHeader({
    super.key,
    required this.albumName,
    this.year,
    this.artist,
  });

  final String albumName;
  final int? year;
  final String? artist;

  @override
  Widget build(BuildContext context) {
    final yearStr = year != null ? ' ($year)' : '';
    final artistStr = artist != null ? ' ${TuiChars.bullet} $artist' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          TuiChars.horizontalDouble * 80,
          style: TuiTextStyles.normal.copyWith(color: TuiColors.primary),
          overflow: TextOverflow.clip,
          maxLines: 1,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            '  $albumName$yearStr$artistStr',
            style: TuiTextStyles.bold.copyWith(color: TuiColors.primary),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        Text(
          TuiChars.horizontalDouble * 80,
          style: TuiTextStyles.normal.copyWith(color: TuiColors.primary),
          overflow: TextOverflow.clip,
          maxLines: 1,
        ),
      ],
    );
  }
}
