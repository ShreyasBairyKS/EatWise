import 'package:flutter/foundation.dart';
import '../../services/ai_service.dart';
import '../scanner/ingredient_parser.dart';

/// Controller for chatbot state management
class ChatbotController extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isScanning = false;
  String? _lastScannedText;
  UserHealthProfile? _userProfile;

  // Getters
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  UserHealthProfile? get userProfile => _userProfile;

  /// Set user health profile for personalized analysis
  void setUserProfile(UserHealthProfile profile) {
    _userProfile = profile;
    notifyListeners();
  }

  /// Add a message to the chat
  void addMessage(ChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  /// Clear all messages
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  /// Set scanning state
  void setScanning(bool scanning) {
    _isScanning = scanning;
    notifyListeners();
  }

  /// Reset scan state to allow re-scanning
  void resetScanState() {
    _lastScannedText = null;
    notifyListeners();
  }

  /// Process raw ingredient text from accessibility service or user input
  Future<void> processIngredients(String rawText) async {
    // Avoid processing same text twice in quick succession
    if (rawText == _lastScannedText && rawText.length < 50) return;
    _lastScannedText = rawText;
    
    // Minimum text length check
    if (rawText.trim().length < 10) {
      return; // Too short to be meaningful
    }
    
    print('Processing text of length: ${rawText.length}');
    print('First 200 chars: ${rawText.substring(0, rawText.length.clamp(0, 200))}');

    _isLoading = true;
    notifyListeners();

    try {
      // Parse ingredients from raw text
      final ingredients = IngredientParser.parse(rawText);
      print('Parsed ${ingredients.length} ingredients');

      if (ingredients.isEmpty) {
        // Try quick extract as fallback for comma-separated lists
        final quickList = IngredientParser.quickExtract(rawText);
        print('Quick extract found ${quickList.length} items');
        
        if (quickList.isNotEmpty && quickList.length >= 2) {
          // Filter out very short or numeric-only items
          final filtered = quickList.where((s) => 
            s.length > 2 && !RegExp(r'^\d+$').hasMatch(s)
          ).toList();
          
          if (filtered.isNotEmpty) {
            // Process as simple list
            addMessage(ChatMessage(
              text: '📋 Analyzing ${filtered.length} items:\n\n'
                  '${filtered.take(10).join(", ")}'
                  '${filtered.length > 10 ? "... and ${filtered.length - 10} more" : ""}',
              isUser: true,
              type: MessageType.ingredients,
            ));
            
            final analysis = await AIService.analyzeIngredients(
              filtered,
              userProfile: _userProfile,
            );
            
            final response = _buildSimpleAnalysisResponse(analysis, filtered);
            addMessage(ChatMessage(
              text: response,
              isUser: false,
              type: MessageType.analysis,
              analysis: analysis,
            ));
            
            _isLoading = false;
            notifyListeners();
            return;
          }
        }
        
        // If substantial text exists, try to send to AI directly
        if (rawText.length > 100) {
          addMessage(ChatMessage(
            text: '📋 Analyzing screen content...',
            isUser: true,
            type: MessageType.ingredients,
          ));
          
          // Extract potential ingredient words from raw text
          final words = rawText
              .replaceAll(RegExp(r'[^\w\s,]'), ' ')
              .split(RegExp(r'[\s,]+'))
              .where((w) => w.length > 2 && !RegExp(r'^\d+$').hasMatch(w))
              .take(30)
              .toList();
          
          if (words.isNotEmpty) {
            final analysis = await AIService.analyzeIngredients(
              words,
              userProfile: _userProfile,
            );
            
            final response = _buildSimpleAnalysisResponse(analysis, words);
            addMessage(ChatMessage(
              text: response,
              isUser: false,
              type: MessageType.analysis,
              analysis: analysis,
            ));
            
            _isLoading = false;
            notifyListeners();
            return;
          }
        }
        
        addMessage(ChatMessage(
          text: '🔍 No ingredients detected.\n\n'
              'Tips:\n'
              '• Make sure the ingredient list is visible on screen\n'
              '• Try scrolling to show the full list\n'
              '• You can also paste ingredients directly here',
          isUser: false,
          type: MessageType.info,
        ));
        _isLoading = false;
        notifyListeners();
        return;
      }

      final ingredientNames = ingredients.map((i) => i.name).toList();

      // Add user message showing detected ingredients
      addMessage(ChatMessage(
        text: '📋 Found ${ingredients.length} ingredients:\n\n'
            '${ingredientNames.take(10).join(", ")}'
            '${ingredients.length > 10 ? "... and ${ingredients.length - 10} more" : ""}',
        isUser: true,
        type: MessageType.ingredients,
      ));

      // Get AI analysis
      final analysis = await AIService.analyzeIngredients(
        ingredientNames,
        userProfile: _userProfile,
      );

      // Build and add response
      final response = _buildAnalysisResponse(analysis, ingredients);
      addMessage(ChatMessage(
        text: response,
        isUser: false,
        type: MessageType.analysis,
        analysis: analysis,
      ));
    } catch (e) {
      addMessage(ChatMessage(
        text: '❌ Analysis failed: ${e.toString()}\n\nPlease try scanning again.',
        isUser: false,
        type: MessageType.error,
      ));
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Build formatted analysis response for simple ingredient list
  String _buildSimpleAnalysisResponse(HealthAnalysis analysis, List<String> ingredients) {
    final buffer = StringBuffer();

    // Health Score
    buffer.writeln('${analysis.ratingEmoji} Health Score: ${analysis.overallRating}/10 (${analysis.ratingText})');
    buffer.writeln();

    // Summary
    buffer.writeln('📝 ${analysis.summary}');

    // Allergens Warning
    if (analysis.allergens.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('🚨 ALLERGENS DETECTED:');
      for (var allergen in analysis.allergens) {
        buffer.writeln('  • $allergen');
      }
    }

    // Concerns
    if (analysis.concerns.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('⚠️ Concerns:');
      for (var concern in analysis.concerns.take(4)) {
        buffer.writeln('  • $concern');
      }
    }

    // Benefits
    if (analysis.benefits.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('✅ Benefits:');
      for (var benefit in analysis.benefits.take(4)) {
        buffer.writeln('  • $benefit');
      }
    }

    // Recommendations
    if (analysis.recommendations.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('💡 Tips:');
      for (var tip in analysis.recommendations.take(3)) {
        buffer.writeln('  • $tip');
      }
    }

    // Disclaimer
    buffer.writeln();
    buffer.writeln('ℹ️ Educational info only. Not medical advice.');

    return buffer.toString();
  }

  /// Build formatted analysis response
  String _buildAnalysisResponse(
      HealthAnalysis analysis, List<Ingredient> ingredients) {
    final buffer = StringBuffer();

    // Health Score
    buffer.writeln('${analysis.ratingEmoji} Health Score: ${analysis.overallRating}/10 (${analysis.ratingText})');
    buffer.writeln();

    // Summary
    buffer.writeln('📝 ${analysis.summary}');

    // Allergens Warning
    if (analysis.allergens.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('🚨 ALLERGENS DETECTED:');
      for (var allergen in analysis.allergens) {
        buffer.writeln('  • $allergen');
      }
    }

    // Concerns
    if (analysis.concerns.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('⚠️ Concerns:');
      for (var concern in analysis.concerns.take(4)) {
        buffer.writeln('  • $concern');
      }
    }

    // Benefits
    if (analysis.benefits.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('✅ Benefits:');
      for (var benefit in analysis.benefits.take(4)) {
        buffer.writeln('  • $benefit');
      }
    }

    // Additives found
    final additives = ingredients.where((i) => i.isAdditive).toList();
    if (additives.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('🔬 Additives found: ${additives.length}');
      buffer.writeln('  ${additives.take(5).map((a) => a.additiveCode ?? a.name).join(", ")}');
    }

    // Recommendations
    if (analysis.recommendations.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('💡 Tips:');
      for (var tip in analysis.recommendations.take(3)) {
        buffer.writeln('  • $tip');
      }
    }

    // Disclaimer
    buffer.writeln();
    buffer.writeln('ℹ️ Educational info only. Not medical advice.');

    return buffer.toString();
  }

  /// Handle user text message
  void sendMessage(String text) {
    if (text.trim().isEmpty) return;

    addMessage(ChatMessage(
      text: text,
      isUser: true,
      type: MessageType.text,
    ));

    // Simple response logic
    final response = _generateResponse(text.toLowerCase());
    addMessage(ChatMessage(
      text: response,
      isUser: false,
      type: MessageType.text,
    ));
  }

  /// Generate response for user questions
  String _generateResponse(String query) {
    if (query.contains('how') && query.contains('use')) {
      return '📱 How to use EatWise:\n\n'
          '1. Open any shopping app (Swiggy, Blinkit, etc.)\n'
          '2. Navigate to a product page\n'
          '3. Tap the floating EatWise icon\n'
          '4. Get instant ingredient analysis!\n\n'
          'The app reads on-screen text to detect ingredients.';
    }

    if (query.contains('sugar') || query.contains('sweet')) {
      return '🍬 About Sugar:\n\n'
          'WHO recommends limiting added sugar to 25g/day.\n\n'
          'Watch out for hidden sugars:\n'
          '• High fructose corn syrup\n'
          '• Dextrose, maltose, sucrose\n'
          '• "Concentrated fruit juice"';
    }

    if (query.contains('msg') || query.contains('e621')) {
      return '🧪 About MSG (E621):\n\n'
          'Monosodium glutamate is a flavor enhancer.\n\n'
          'Generally recognized as safe (GRAS), but some people may experience:\n'
          '• Headaches\n'
          '• Flushing\n'
          '• Sweating\n\n'
          'If sensitive, look for "No MSG" products.';
    }

    if (query.contains('preservative')) {
      return '🔬 Common Preservatives:\n\n'
          '⚠️ Caution:\n'
          '• Sodium Nitrite (E250)\n'
          '• Sodium Benzoate (E211)\n'
          '• BHA/BHT\n\n'
          '✅ Generally Safe:\n'
          '• Citric Acid (E330)\n'
          '• Ascorbic Acid (E300)\n'
          '• Tocopherols (Vitamin E)';
    }

    // Default response
    return '🍎 I can help you understand food ingredients!\n\n'
        'Try:\n'
        '• Scanning a product in any shopping app\n'
        '• Asking about specific ingredients\n'
        '• Questions about additives or preservatives\n\n'
        'Tap the scan icon to analyze a product!';
  }
}

/// Types of chat messages
enum MessageType {
  text,
  ingredients,
  analysis,
  info,
  error,
}

/// Chat message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final MessageType type;
  final HealthAnalysis? analysis;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.type = MessageType.text,
    this.analysis,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
