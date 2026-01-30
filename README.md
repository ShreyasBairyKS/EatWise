# 🍎 EatWise

**Background Ingredient Intelligence Chatbot** - Analyze food ingredients in real-time using AI.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

## 📖 About

EatWise is a Flutter-based mobile application that helps users make informed food choices by analyzing ingredient lists in real-time. Simply scan any food product's ingredient list, and the AI-powered chatbot will provide insights about the ingredients, potential allergens, and health implications.

## ✨ Features

- 🔍 **Real-time OCR Scanning** - Scan ingredient lists using your camera with Google ML Kit
- 🤖 **AI-Powered Analysis** - Get intelligent insights about ingredients using GPT-4o
- 💬 **Interactive Chatbot** - Ask follow-up questions about ingredients and nutrition
- 📱 **Background Scanning** - Overlay service for scanning while using other apps
- 🎯 **Ingredient Detection** - Smart parsing and recognition of ingredient lists

## 🛠️ Tech Stack

- **Framework**: Flutter 3.9+
- **Language**: Dart
- **State Management**: Provider
- **OCR**: Google ML Kit Text Recognition
- **AI**: OpenRouter API (GPT-4o)
- **Platform**: Android (Kotlin)

## 📋 Prerequisites

- Flutter SDK 3.9.2 or higher
- Android Studio / VS Code
- Android device or emulator (API 21+)
- OpenRouter API key

## 🚀 Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/ShreyasBairyKS/EatWise.git
cd EatWise
```

### 2. Configure API Key

Copy the template config file and add your API key:

```bash
cp lib/core/api_config.template.dart lib/core/api_config.dart
```

Edit `lib/core/api_config.dart` and replace `YOUR_API_KEY_HERE` with your OpenRouter API key:

```dart
class ApiConfig {
  static const String apiKey = 'your-openrouter-api-key-here';
}
```

> 🔑 Get your API key at [OpenRouter](https://openrouter.ai/keys)

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Run the app

```bash
flutter run
```

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── core/
│   ├── constants.dart        # App constants & configuration
│   ├── knowledge_base.dart   # Ingredient knowledge base
│   └── platform_channel.dart # Flutter ↔ Kotlin bridge
├── features/
│   ├── chatbot/
│   │   ├── chat_screen.dart      # Chat UI
│   │   ├── chatbot_controller.dart # Chat state management
│   │   └── home_screen.dart      # Home screen
│   └── scanner/
│       └── ingredient_parser.dart # Ingredient parsing logic
└── services/
    └── ai_service.dart       # OpenRouter API integration
```

## 🔒 Security Note

The `api_config.dart` file containing your API key is gitignored and will not be pushed to the repository. Never commit API keys or secrets to version control.

## 📄 License

This project is for educational purposes.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

---

Made with ❤️ using Flutter
