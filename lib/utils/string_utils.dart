/// Utility for string manipulation and normalization.
class StringUtils {
  /// Cleans a name for sorting by removing articles (A, An, The) 
  /// and stripping leading symbols/punctuation.
  static String getSortName(String name) {
    var cleaned = name.trim();
    final lower = cleaned.toLowerCase();
    
    if (lower.startsWith('the ')) {
      cleaned = cleaned.substring(4).trim();
    } else if (lower.startsWith('a ')) {
      cleaned = cleaned.substring(2).trim();
    } else if (lower.startsWith('an ')) {
      cleaned = cleaned.substring(3).trim();
    }
    
    // Strip common starting punctuation/symbols to find the "real" first letter
    // e.g. "[Untitled]" -> "Untitled", "(Live)" -> "Live"
    cleaned = cleaned.replaceAll(RegExp(r'^[^a-zA-Z0-9À-ÖØ-Þ]+'), '');
    
    if (cleaned.isEmpty) return name; // Fallback to original if completely stripped
    return cleaned;
  }
}
