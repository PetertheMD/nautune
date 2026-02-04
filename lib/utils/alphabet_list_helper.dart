
abstract class AlphabetListItem<T> {}

class AlphabetHeaderItem<T> extends AlphabetListItem<T> {
  final String letter;
  AlphabetHeaderItem(this.letter);
}

class AlphabetContentItem<T> extends AlphabetListItem<T> {
  final T item;
  AlphabetContentItem(this.item);
}

class AlphabetListHelper {
  /// Flattens a list of items into a list of items and headers.
  /// Also returns a map of scroll offsets for each letter.
  static ({
    List<AlphabetListItem<T>> flatList,
    Map<String, double> offsets,
  }) processItems<T>({
    required List<T> items,
    required String Function(T) getName,
    required double headerHeight,
    required double itemHeight,
    // For Grid views:
    int crossAxisCount = 1,
    double mainAxisSpacing = 0.0,
    double sectionPadding = 0.0,
  }) {
    if (items.isEmpty) {
      return (flatList: [], offsets: {});
    }

    final List<AlphabetListItem<T>> flatList = [];
    final Map<String, double> offsets = {};
    final Map<String, List<T>> groups = {};
    final List<String> orderedLetters = [];

    // 1. Group items
    for (final item in items) {
      final name = getName(item).toUpperCase();
      if (name.isEmpty) continue;
      
      final firstChar = name[0];
      String letter;
      
      if (RegExp(r'[0-9]').hasMatch(firstChar)) {
        letter = '#';
      } else if (RegExp(r'[A-ZÀ-ÖØ-Þ]').hasMatch(firstChar)) {
        letter = firstChar;
      } else {
        letter = '#';
      }
      
      if (!groups.containsKey(letter)) {
        orderedLetters.add(letter);
        groups[letter] = [];
      }
      groups[letter]!.add(item);
    }

    // 2. Build flat list and calculate offsets
    double currentOffset = 0.0;

    for (final letter in orderedLetters) {
      final groupItems = groups[letter]!;
      
      // Record offset for this letter (points to the Header)
      offsets[letter] = currentOffset;

      // Add Header
      flatList.add(AlphabetHeaderItem<T>(letter));
      currentOffset += headerHeight;
      
      // Add padding ABOVE items (e.g. 8px)
      currentOffset += sectionPadding / 2;

      // Add Items to flat list
      for (final item in groupItems) {
        flatList.add(AlphabetContentItem<T>(item));
      }

      // Update offset for items
      if (crossAxisCount == 1) {
        // List Mode
        currentOffset += groupItems.length * itemHeight;
      } else {
        // Grid Mode
        final rows = (groupItems.length / crossAxisCount).ceil();
        currentOffset += rows * itemHeight;
        if (rows > 0) currentOffset += (rows - 1) * mainAxisSpacing;
      }
      
      // Add padding BELOW items (e.g. 8px)
      currentOffset += sectionPadding / 2;
    }

    return (flatList: flatList, offsets: offsets);
  }
}
