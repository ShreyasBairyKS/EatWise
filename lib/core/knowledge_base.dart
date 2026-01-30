/// Local knowledge base for common food ingredients and additives
class IngredientKnowledgeBase {
  static final Map<String, IngredientInfo> _database = {
    // Sweeteners
    'sugar': IngredientInfo(
      category: 'Sweetener',
      healthImpact: HealthImpact.negative,
      concerns: ['Blood sugar spike', 'Weight gain', 'Dental issues'],
      dailyLimit: '25g (WHO recommendation)',
    ),
    'high fructose corn syrup': IngredientInfo(
      category: 'Sweetener',
      healthImpact: HealthImpact.negative,
      concerns: ['Obesity risk', 'Metabolic issues', 'Liver stress'],
    ),
    'aspartame': IngredientInfo(
      category: 'Artificial Sweetener',
      healthImpact: HealthImpact.caution,
      commonName: 'E951',
      concerns: ['May cause headaches in sensitive individuals'],
    ),
    'stevia': IngredientInfo(
      category: 'Natural Sweetener',
      healthImpact: HealthImpact.positive,
      benefits: ['Zero calories', 'Natural origin', 'Doesn\'t spike blood sugar'],
    ),

    // Fats & Oils
    'palm oil': IngredientInfo(
      category: 'Fat',
      healthImpact: HealthImpact.negative,
      concerns: ['High saturated fat', 'Environmental concerns'],
      alternatives: ['Coconut oil', 'Olive oil', 'Sunflower oil'],
    ),
    'trans fat': IngredientInfo(
      category: 'Fat',
      healthImpact: HealthImpact.negative,
      concerns: ['Heart disease risk', 'Bad cholesterol increase'],
    ),
    'olive oil': IngredientInfo(
      category: 'Fat',
      healthImpact: HealthImpact.positive,
      benefits: ['Heart healthy', 'Rich in antioxidants', 'Anti-inflammatory'],
    ),
    'partially hydrogenated': IngredientInfo(
      category: 'Fat',
      healthImpact: HealthImpact.negative,
      concerns: ['Contains trans fats', 'Heart disease risk'],
    ),

    // Preservatives
    'sodium benzoate': IngredientInfo(
      category: 'Preservative',
      healthImpact: HealthImpact.caution,
      commonName: 'E211',
      concerns: ['May form benzene with Vitamin C', 'Hyperactivity in children'],
    ),
    'potassium sorbate': IngredientInfo(
      category: 'Preservative',
      healthImpact: HealthImpact.neutral,
      commonName: 'E202',
      concerns: ['Generally safe', 'Rare skin sensitivity'],
    ),
    'sodium nitrite': IngredientInfo(
      category: 'Preservative',
      healthImpact: HealthImpact.caution,
      commonName: 'E250',
      concerns: ['May form nitrosamines', 'Linked to certain cancers'],
    ),

    // Flavor Enhancers
    'monosodium glutamate': IngredientInfo(
      category: 'Flavor Enhancer',
      healthImpact: HealthImpact.caution,
      commonName: 'MSG / E621',
      concerns: ['May cause headaches', 'Chinese Restaurant Syndrome'],
    ),
    'msg': IngredientInfo(
      category: 'Flavor Enhancer',
      healthImpact: HealthImpact.caution,
      commonName: 'E621',
      concerns: ['May cause headaches in sensitive individuals'],
    ),

    // Colors
    'tartrazine': IngredientInfo(
      category: 'Artificial Color',
      healthImpact: HealthImpact.caution,
      commonName: 'E102 / Yellow 5',
      concerns: ['Hyperactivity', 'Allergic reactions', 'Asthma trigger'],
    ),
    'caramel color': IngredientInfo(
      category: 'Color',
      healthImpact: HealthImpact.caution,
      commonName: 'E150',
      concerns: ['Some types may contain 4-MEI (potential carcinogen)'],
    ),

    // E-Numbers (Common Additives)
    'e621': IngredientInfo(
      category: 'Flavor Enhancer',
      healthImpact: HealthImpact.caution,
      commonName: 'MSG',
      concerns: ['May cause headaches in sensitive individuals'],
    ),
    'e211': IngredientInfo(
      category: 'Preservative',
      healthImpact: HealthImpact.caution,
      commonName: 'Sodium Benzoate',
      concerns: ['May form benzene with Vitamin C'],
    ),
    'e102': IngredientInfo(
      category: 'Color',
      healthImpact: HealthImpact.caution,
      commonName: 'Tartrazine',
      concerns: ['Hyperactivity', 'Allergic reactions'],
    ),
    'e330': IngredientInfo(
      category: 'Acidity Regulator',
      healthImpact: HealthImpact.neutral,
      commonName: 'Citric Acid',
      benefits: ['Natural preservative', 'Found in citrus fruits'],
    ),
    'e300': IngredientInfo(
      category: 'Antioxidant',
      healthImpact: HealthImpact.positive,
      commonName: 'Vitamin C / Ascorbic Acid',
      benefits: ['Natural antioxidant', 'Immune support'],
    ),

    // Healthy Ingredients
    'whole wheat': IngredientInfo(
      category: 'Grain',
      healthImpact: HealthImpact.positive,
      benefits: ['High fiber', 'Complex carbs', 'Better blood sugar control'],
    ),
    'oats': IngredientInfo(
      category: 'Grain',
      healthImpact: HealthImpact.positive,
      benefits: ['High fiber', 'Heart healthy', 'Lowers cholesterol'],
    ),
    'quinoa': IngredientInfo(
      category: 'Grain',
      healthImpact: HealthImpact.positive,
      benefits: ['Complete protein', 'Gluten-free', 'Rich in minerals'],
    ),
  };

  /// Look up ingredient information
  static IngredientInfo? lookup(String ingredientName) {
    final normalized = ingredientName.toLowerCase().trim();
    
    // Direct lookup
    if (_database.containsKey(normalized)) {
      return _database[normalized];
    }
    
    // Partial match
    for (final entry in _database.entries) {
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        return entry.value;
      }
    }
    
    return null;
  }

  /// Get all ingredients in a specific category
  static List<String> getByCategory(String category) {
    return _database.entries
        .where((e) => e.value.category.toLowerCase() == category.toLowerCase())
        .map((e) => e.key)
        .toList();
  }
}

/// Health impact levels
enum HealthImpact {
  positive,
  neutral,
  caution,
  negative,
}

/// Information about a food ingredient
class IngredientInfo {
  final String category;
  final HealthImpact healthImpact;
  final String? commonName;
  final List<String> concerns;
  final List<String>? benefits;
  final String? dailyLimit;
  final List<String>? alternatives;

  const IngredientInfo({
    required this.category,
    required this.healthImpact,
    this.commonName,
    this.concerns = const [],
    this.benefits,
    this.dailyLimit,
    this.alternatives,
  });

  String get healthImpactEmoji {
    switch (healthImpact) {
      case HealthImpact.positive:
        return '✅';
      case HealthImpact.neutral:
        return '⚪';
      case HealthImpact.caution:
        return '⚠️';
      case HealthImpact.negative:
        return '❌';
    }
  }

  String get healthImpactText {
    switch (healthImpact) {
      case HealthImpact.positive:
        return 'Good';
      case HealthImpact.neutral:
        return 'Neutral';
      case HealthImpact.caution:
        return 'Caution';
      case HealthImpact.negative:
        return 'Avoid';
    }
  }
}
