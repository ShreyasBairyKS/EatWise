import '../../core/constants.dart';

/// Parses raw ingredient text into structured ingredient list
class IngredientParser {
  // Common additive patterns (E-numbers, INS codes)
  static final RegExp _additivePattern = RegExp(
    r'(E\d{3,4}[a-z]?|INS\s?\d{3,4})',
    caseSensitive: false,
  );

  // Ingredient separators
  static final RegExp _separatorPattern = RegExp(r'[,;|•·]');

  // Percentage pattern
  static final RegExp _percentagePattern = RegExp(r'\d+\.?\d*\s*%');

  /// Parse raw text into list of ingredients
  static List<Ingredient> parse(String rawText) {
    // First, extract the ingredient block
    final ingredientBlock = _extractIngredientBlock(rawText);
    if (ingredientBlock.isEmpty) {
      return [];
    }

    // Clean the text
    String cleaned = ingredientBlock
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\[.*?\]'), '') // Remove bracketed content
        .trim();

    // Handle parentheses - items inside are sub-ingredients
    cleaned = _flattenParentheses(cleaned);

    // Split by separators
    List<String> parts = cleaned.split(_separatorPattern);

    List<Ingredient> ingredients = [];
    for (var part in parts) {
      String name = part.trim();
      if (name.isEmpty || name.length < 2) continue;

      // Skip if it's just a number or percentage
      if (RegExp(r'^\d+\.?\d*%?$').hasMatch(name)) continue;

      // Extract percentage if present
      String? percentage;
      final percentMatch = _percentagePattern.firstMatch(name);
      if (percentMatch != null) {
        percentage = percentMatch.group(0);
        name = name.replaceAll(_percentagePattern, '').trim();
      }

      // Check if it's an additive
      bool isAdditive = _additivePattern.hasMatch(name);
      String? additiveCode = _extractAdditiveCode(name);

      // Normalize the name
      name = _normalizeIngredientName(name);

      if (name.isNotEmpty && name.length >= 2) {
        ingredients.add(Ingredient(
          name: name,
          isAdditive: isAdditive,
          additiveCode: additiveCode,
          percentage: percentage,
        ));
      }
    }

    return ingredients;
  }

  /// Extract the ingredient block from full text
  static String _extractIngredientBlock(String text) {
    final lowerText = text.toLowerCase();

    // Find ingredient anchor
    int startIndex = -1;
    for (final anchor in IngredientKeywords.anchors) {
      final idx = lowerText.indexOf(anchor);
      if (idx != -1) {
        startIndex = idx + anchor.length;
        break;
      }
    }

    if (startIndex == -1) {
      // No anchor found - return empty, don't process random text
      return '';
    }

    // Find end of ingredient section
    int endIndex = text.length;
    for (final stop in IngredientKeywords.stopWords) {
      final idx = lowerText.indexOf(stop, startIndex + 5);
      if (idx != -1 && idx < endIndex) {
        endIndex = idx;
      }
    }

    return text.substring(startIndex, endIndex).trim();
  }

  /// Flatten parentheses content
  static String _flattenParentheses(String text) {
    // Replace ( with , and remove )
    return text
        .replaceAll('(', ', ')
        .replaceAll(')', '')
        .replaceAll(RegExp(r',\s*,'), ',');
  }

  /// Normalize ingredient name
  static String _normalizeIngredientName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'^\d+\.?\s*'), '') // Remove numbering
        .replaceAll(RegExp(r'\*+'), '') // Remove asterisks
        .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove special chars
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .trim();
  }

  /// Extract additive code from name
  static String? _extractAdditiveCode(String name) {
    final match = _additivePattern.firstMatch(name);
    return match?.group(0)?.toUpperCase();
  }

  /// Simple text extraction without full parsing
  static List<String> quickExtract(String text) {
    final block = _extractIngredientBlock(text);
    return block
        .split(_separatorPattern)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length >= 2)
        .toList();
  }
}

/// Represents a parsed ingredient
class Ingredient {
  final String name;
  final bool isAdditive;
  final String? additiveCode;
  final String? percentage;

  Ingredient({
    required this.name,
    required this.isAdditive,
    this.additiveCode,
    this.percentage,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'isAdditive': isAdditive,
        'additiveCode': additiveCode,
        'percentage': percentage,
      };

  @override
  String toString() {
    if (additiveCode != null) {
      return '$name ($additiveCode)';
    }
    if (percentage != null) {
      return '$name ($percentage)';
    }
    return name;
  }
}
