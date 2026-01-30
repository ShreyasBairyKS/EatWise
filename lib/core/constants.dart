import 'api_config.dart';

/// App-wide constants
class AppConstants {
  // Channel names for Flutter ↔ Kotlin communication
  static const String methodChannel = 'com.eatwise/methods';
  static const String eventChannel = 'com.eatwise/events';
  
  // API Configuration - Supports OpenRouter or OpenAI
  // Get your OpenRouter key at: https://openrouter.ai/keys
  // API key is stored in api_config.dart (gitignored)
  static const String apiKey = ApiConfig.apiKey;
  
  // Set to true to use OpenRouter, false for direct OpenAI
  static const bool useOpenRouter = true;
  
  // OpenRouter endpoint and model
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const String openRouterModel = 'openai/gpt-4o';  // Latest OpenAI model
  // Alternative models:
  // 'openai/gpt-4o'                     // Best OpenAI (current)
  // 'anthropic/claude-sonnet-4'         // Best Anthropic
  // 'google/gemini-2.0-flash-001'       // Fast & cheap
  // 'google/gemini-2.0-flash-lite-001'  // Cheapest
  
  // Direct OpenAI endpoint (if not using OpenRouter)
  static const String openAiBaseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String openAiModel = 'gpt-4o-mini';
  
  // App Info
  static const String appName = 'EatWise';
  static const String appVersion = '1.0.0';
  
  // Shared Preferences Keys
  static const String prefUserConsented = 'user_consented';
  static const String prefUserProfile = 'user_profile';
  static const String prefOnboardingComplete = 'onboarding_complete';
}

/// Ingredient keyword anchors for detection
class IngredientKeywords {
  static const List<String> anchors = [
    'ingredients:',
    'ingredients',
    'contains:',
    'contains',
    'composition:',
    'composition',
    'made with',
    'made from',
    'contents:',
    'contents',
    'ingredients list',
  ];
  
  static const List<String> stopWords = [
    'allergen',
    'allergy',
    'allergy advice',
    'storage',
    'store in',
    'nutritional',
    'nutrition facts',
    'nutrition information',
    'directions',
    'best before',
    'expiry',
    'exp date',
    'manufactured',
    'packed by',
    'marketed by',
    'fssai',
    'net weight',
    'net wt',
    'net qty',
    'serving size',
    'how to use',
    'customer care',
    'disclaimer',
    'warning',
  ];
}
