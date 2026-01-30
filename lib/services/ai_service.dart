import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/knowledge_base.dart';

/// Service for AI-powered ingredient analysis
class AIService {
  /// Analyze ingredients and return health insights
  static Future<HealthAnalysis> analyzeIngredients(
    List<String> ingredients, {
    UserHealthProfile? userProfile,
  }) async {
    // Check for empty ingredients
    if (ingredients.isEmpty) {
      return HealthAnalysis(
        summary: 'No ingredients were provided for analysis.',
        concerns: [],
        benefits: [],
        overallRating: 1,
        recommendations: ['Please provide a list of ingredients for analysis.'],
        allergens: [],
      );
    }

    // If no API key configured, use local analysis
    if (AppConstants.apiKey == 'YOUR_API_KEY_HERE' || 
        AppConstants.apiKey.isEmpty ||
        AppConstants.apiKey.contains('\n')) {
      print('Using local analysis - API key not configured properly');
      return _localAnalysis(ingredients, userProfile);
    }

    try {
      final prompt = _buildPrompt(ingredients, userProfile);
      
      // Determine endpoint and model based on configuration
      final String baseUrl = AppConstants.useOpenRouter 
          ? AppConstants.openRouterBaseUrl 
          : AppConstants.openAiBaseUrl;
      final String model = AppConstants.useOpenRouter 
          ? AppConstants.openRouterModel 
          : AppConstants.openAiModel;
      
      print('Calling AI API: $baseUrl with model: $model');
      print('Analyzing ${ingredients.length} ingredients: ${ingredients.take(5).join(", ")}...');
      
      // Build headers
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConstants.apiKey.trim()}',
      };
      
      // Add OpenRouter specific headers
      if (AppConstants.useOpenRouter) {
        headers['HTTP-Referer'] = 'https://eatwise.app';
        headers['X-Title'] = 'EatWise Ingredient Analyzer';
      }

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': '''You are a food ingredient analyst specializing in health and nutrition.
Analyze the provided ingredients and give concise, factual health insights.
Focus on:
- Identifying harmful additives (E-numbers, preservatives, artificial colors)
- Highlighting healthy vs unhealthy ingredients
- Noting potential allergens
- Providing an overall health rating

IMPORTANT: Be factual, not alarmist. Mention if something is generally safe in normal quantities.

Respond ONLY with valid JSON (no markdown, no code blocks):
{
  "summary": "Brief 1-2 sentence summary",
  "overallRating": 1-10,
  "concerns": ["concern1", "concern2"],
  "benefits": ["benefit1", "benefit2"],
  "recommendations": ["tip1", "tip2"],
  "allergens": ["allergen1"] 
}'''
            },
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.3,
          'max_tokens': 600,
        }),
      ).timeout(const Duration(seconds: 30));

      print('AI API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        print('AI Response received: ${content.toString().substring(0, content.toString().length.clamp(0, 100))}...');
        
        // Parse JSON from response (handle markdown code blocks)
        String jsonStr = content.toString().trim();
        if (jsonStr.contains('```')) {
          jsonStr = jsonStr
              .replaceAll('```json', '')
              .replaceAll('```', '')
              .trim();
        }
        
        // Try to extract JSON if there's extra text
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
        if (jsonMatch != null) {
          jsonStr = jsonMatch.group(0)!;
        }
        
        return HealthAnalysis.fromJson(jsonDecode(jsonStr));
      } else {
        print('AI API Error: ${response.statusCode} - ${response.body}');
        return _localAnalysis(ingredients, userProfile);
      }
    } catch (e, stackTrace) {
      print('AI Analysis Error: $e');
      print('Stack trace: $stackTrace');
      return _localAnalysis(ingredients, userProfile);
    }
  }

  /// Build prompt for AI analysis
  static String _buildPrompt(
      List<String> ingredients, UserHealthProfile? profile) {
    final buffer = StringBuffer();

    buffer.writeln('Analyze these food ingredients:');
    buffer.writeln(ingredients.join(', '));

    if (profile != null) {
      buffer.writeln('\n--- User Health Profile ---');
      if (profile.allergies.isNotEmpty) {
        buffer.writeln('Allergies: ${profile.allergies.join(", ")}');
      }
      if (profile.dietaryRestrictions.isNotEmpty) {
        buffer.writeln('Diet: ${profile.dietaryRestrictions.join(", ")}');
      }
      if (profile.healthConditions.isNotEmpty) {
        buffer.writeln('Health conditions: ${profile.healthConditions.join(", ")}');
      }
    }

    return buffer.toString();
  }

  /// Local fallback analysis when API is not available
  static HealthAnalysis _localAnalysis(
      List<String> ingredients, UserHealthProfile? profile) {
    List<String> concerns = [];
    List<String> benefits = [];
    List<String> allergens = [];
    int score = 7; // Start with neutral score

    // Common concerning ingredients
    final badIngredients = {
      'sugar': 'High sugar content',
      'added sugar': 'Contains added sugars',
      'palm oil': 'Contains palm oil (high saturated fat)',
      'high fructose corn syrup': 'Contains HFCS',
      'corn syrup': 'Contains corn syrup (high sugar)',
      'trans fat': 'Contains trans fats',
      'hydrogenated': 'Contains hydrogenated fats',
      'partially hydrogenated': 'Contains trans fats (partially hydrogenated)',
      'msg': 'Contains MSG (may cause sensitivity)',
      'monosodium glutamate': 'Contains MSG',
      'e621': 'Contains MSG (E621)',
      'sodium nitrite': 'Contains sodium nitrite (preservative)',
      'e250': 'Contains sodium nitrite (E250)',
      'sodium nitrate': 'Contains sodium nitrate',
      'e251': 'Contains sodium nitrate (E251)',
      'artificial color': 'Contains artificial colors',
      'artificial flavour': 'Contains artificial flavors',
      'artificial flavor': 'Contains artificial flavors',
      'tartrazine': 'Contains Tartrazine (E102) - artificial color',
      'e102': 'Contains artificial color (E102)',
      'e110': 'Contains Sunset Yellow (E110)',
      'e124': 'Contains artificial color (E124)',
      'e129': 'Contains artificial color (E129)',
      'aspartame': 'Contains aspartame (artificial sweetener)',
      'e951': 'Contains aspartame (E951)',
      'acesulfame': 'Contains artificial sweetener',
      'e950': 'Contains acesulfame-K (E950)',
      'sodium benzoate': 'Contains sodium benzoate (preservative)',
      'e211': 'Contains sodium benzoate (E211)',
      'potassium bromate': 'Contains potassium bromate (banned in many countries)',
      'bha': 'Contains BHA (preservative)',
      'bht': 'Contains BHT (preservative)',
      'e320': 'Contains BHA (E320)',
      'e321': 'Contains BHT (E321)',
      'carrageenan': 'Contains carrageenan (may cause digestive issues)',
      'e407': 'Contains carrageenan (E407)',
      'refined': 'Contains refined ingredients',
      'bleached': 'Contains bleached flour',
      'maida': 'Contains refined flour (maida)',
    };

    final goodIngredients = {
      'whole wheat': 'Contains whole grains',
      'whole grain': 'Contains whole grains',
      'oats': 'Contains heart-healthy oats',
      'olive oil': 'Contains heart-healthy olive oil',
      'coconut oil': 'Contains coconut oil',
      'fiber': 'Good source of fiber',
      'protein': 'Contains protein',
      'vitamin': 'Contains vitamins',
      'mineral': 'Contains minerals',
      'calcium': 'Good source of calcium',
      'iron': 'Contains iron',
      'omega': 'Contains omega fatty acids',
      'antioxidant': 'Contains antioxidants',
      'probiotic': 'Contains probiotics',
      'natural': 'Contains natural ingredients',
      'organic': 'Organic ingredient',
      'no added sugar': 'No added sugar',
      'honey': 'Contains natural sweetener (honey)',
      'jaggery': 'Contains natural sweetener (jaggery)',
      'nuts': 'Contains healthy nuts',
      'seeds': 'Contains healthy seeds',
      'lentil': 'Contains lentils (good protein)',
      'dal': 'Contains dal (good protein)',
      'chickpea': 'Contains chickpeas',
      'quinoa': 'Contains quinoa (superfood)',
      'millet': 'Contains millet (whole grain)',
      'ragi': 'Contains ragi (nutritious millet)',
    };

    final allergenList = {
      'milk': 'Dairy',
      'dairy': 'Dairy',
      'cream': 'Dairy',
      'butter': 'Dairy',
      'cheese': 'Dairy',
      'whey': 'Dairy',
      'casein': 'Dairy',
      'lactose': 'Dairy',
      'egg': 'Eggs',
      'peanut': 'Peanuts',
      'groundnut': 'Peanuts',
      'tree nut': 'Tree Nuts',
      'almond': 'Tree Nuts',
      'cashew': 'Tree Nuts',
      'walnut': 'Tree Nuts',
      'pistachio': 'Tree Nuts',
      'hazelnut': 'Tree Nuts',
      'wheat': 'Wheat/Gluten',
      'gluten': 'Gluten',
      'barley': 'Gluten (Barley)',
      'rye': 'Gluten (Rye)',
      'soy': 'Soy',
      'soya': 'Soy',
      'fish': 'Fish',
      'shellfish': 'Shellfish',
      'shrimp': 'Shellfish',
      'crab': 'Shellfish',
      'lobster': 'Shellfish',
      'sesame': 'Sesame',
      'mustard': 'Mustard',
      'celery': 'Celery',
      'sulphite': 'Sulphites',
      'sulfite': 'Sulphites',
      'e220': 'Sulphites (E220)',
    };

    for (final ingredient in ingredients) {
      final lower = ingredient.toLowerCase();

      // First check knowledge base for detailed info
      final kbInfo = IngredientKnowledgeBase.lookup(ingredient);
      if (kbInfo != null) {
        switch (kbInfo.healthImpact) {
          case HealthImpact.negative:
            for (var concern in kbInfo.concerns) {
              if (!concerns.contains(concern)) concerns.add(concern);
            }
            score -= 2;
            break;
          case HealthImpact.caution:
            for (var concern in kbInfo.concerns) {
              if (!concerns.contains(concern)) concerns.add(concern);
            }
            score -= 1;
            break;
          case HealthImpact.positive:
            if (kbInfo.benefits != null) {
              for (var benefit in kbInfo.benefits!) {
                if (!benefits.contains(benefit)) benefits.add(benefit);
              }
            }
            score += 1;
            break;
          case HealthImpact.neutral:
            // No score change
            break;
        }
        continue; // Skip standard checks if found in knowledge base
      }

      // Check bad ingredients
      for (final entry in badIngredients.entries) {
        if (lower.contains(entry.key)) {
          if (!concerns.contains(entry.value)) {
            concerns.add(entry.value);
            score -= 1;
          }
        }
      }

      // Check good ingredients
      for (final entry in goodIngredients.entries) {
        if (lower.contains(entry.key)) {
          if (!benefits.contains(entry.value)) {
            benefits.add(entry.value);
            score += 1;
          }
        }
      }

      // Check allergens
      for (final entry in allergenList.entries) {
        if (lower.contains(entry.key)) {
          if (!allergens.contains(entry.value)) {
            allergens.add(entry.value);
          }
        }
      }
    }

    // Clamp score
    score = score.clamp(1, 10).toInt();

    // Check user allergies
    if (profile != null && profile.allergies.isNotEmpty) {
      for (final allergy in profile.allergies) {
        if (allergens.any(
            (a) => a.toLowerCase().contains(allergy.toLowerCase()))) {
          concerns.insert(0, '⚠️ CONTAINS YOUR ALLERGEN: $allergy');
        }
      }
    }

    // Generate summary
    String summary;
    if (score >= 7) {
      summary = 'This product appears to be relatively healthy with ${ingredients.length} ingredients.';
    } else if (score >= 4) {
      summary = 'This product has some concerns. Consume in moderation.';
    } else {
      summary = 'This product contains several concerning ingredients. Consider healthier alternatives.';
    }

    // Recommendations
    List<String> recommendations = [];
    if (concerns.isNotEmpty) {
      recommendations.add('Look for products with fewer additives');
    }
    if (allergens.isNotEmpty) {
      recommendations.add('Check if you have sensitivities to: ${allergens.join(", ")}');
    }
    if (score < 5) {
      recommendations.add('Consider whole food alternatives');
    }

    return HealthAnalysis(
      summary: summary,
      concerns: concerns.take(5).toList(),
      benefits: benefits.take(5).toList(),
      overallRating: score,
      recommendations: recommendations,
      allergens: allergens,
    );
  }
}

/// Health analysis result
class HealthAnalysis {
  final String summary;
  final List<String> concerns;
  final List<String> benefits;
  final int overallRating;
  final List<String> recommendations;
  final List<String> allergens;

  HealthAnalysis({
    required this.summary,
    required this.concerns,
    required this.benefits,
    required this.overallRating,
    required this.recommendations,
    this.allergens = const [],
  });

  factory HealthAnalysis.fromJson(Map<String, dynamic> json) {
    return HealthAnalysis(
      summary: json['summary'] ?? 'Analysis complete.',
      concerns: List<String>.from(json['concerns'] ?? []),
      benefits: List<String>.from(json['benefits'] ?? []),
      overallRating: (json['overallRating'] ?? 5).toInt().clamp(1, 10),
      recommendations: List<String>.from(json['recommendations'] ?? []),
      allergens: List<String>.from(json['allergens'] ?? []),
    );
  }

  String get ratingEmoji {
    if (overallRating >= 8) return '🌟';
    if (overallRating >= 6) return '✅';
    if (overallRating >= 4) return '⚠️';
    return '❌';
  }

  String get ratingText {
    if (overallRating >= 8) return 'Excellent';
    if (overallRating >= 6) return 'Good';
    if (overallRating >= 4) return 'Fair';
    return 'Poor';
  }
}

/// User health profile for personalized analysis
class UserHealthProfile {
  final List<String> allergies;
  final List<String> dietaryRestrictions;
  final List<String> healthConditions;

  UserHealthProfile({
    this.allergies = const [],
    this.dietaryRestrictions = const [],
    this.healthConditions = const [],
  });

  factory UserHealthProfile.fromJson(Map<String, dynamic> json) {
    return UserHealthProfile(
      allergies: List<String>.from(json['allergies'] ?? []),
      dietaryRestrictions: List<String>.from(json['dietaryRestrictions'] ?? []),
      healthConditions: List<String>.from(json['healthConditions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'allergies': allergies,
        'dietaryRestrictions': dietaryRestrictions,
        'healthConditions': healthConditions,
      };

  bool get isEmpty =>
      allergies.isEmpty &&
      dietaryRestrictions.isEmpty &&
      healthConditions.isEmpty;
}
