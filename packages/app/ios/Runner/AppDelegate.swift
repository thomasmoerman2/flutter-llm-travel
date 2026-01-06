import Flutter
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let appleFoundationProvider = AppleFoundationAIProvider()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Set up Apple Intelligence MethodChannel
    let controller = window?.rootViewController as! FlutterViewController
    let appleIntelligenceChannel = FlutterMethodChannel(
      name: "com.travel.app/apple_intelligence",
      binaryMessenger: controller.binaryMessenger
    )

    appleIntelligenceChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "initialize":
        self.initializeAppleIntelligence(result: result)
      case "sendMessage":
        if let args = call.arguments as? [String: Any],
           let message = args["message"] as? String,
           let conversationHistory = args["conversationHistory"] as? [[String: Any]] {
          self.sendMessageToAppleIntelligence(
            message: message,
            history: conversationHistory,
            result: result
          )
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        }
      case "isAvailable":
        self.checkAppleIntelligenceAvailability(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Apple Intelligence Methods

  private func initializeAppleIntelligence(result: @escaping FlutterResult) {
    if AppleFoundationAIProvider.isAvailable() {
      print("✅ Apple Foundation initialized")
      result(true)
      return
    }

    result(FlutterError(
      code: "UNAVAILABLE",
      message: "Apple Foundation requires Apple Intelligence on-device (iOS 26.0+)",
      details: nil
    ))
  }

  private func checkAppleIntelligenceAvailability(result: @escaping FlutterResult) {
    result(AppleFoundationAIProvider.isAvailable())
  }

  private func sendMessageToAppleIntelligence(
    message: String,
    history: [[String: Any]],
    result: @escaping FlutterResult
  ) {
    guard AppleFoundationAIProvider.isAvailable() else {
      result(FlutterError(
        code: "UNAVAILABLE",
        message: "Apple Foundation is not available on this device",
        details: nil
      ))
      return
    }

    let prompt = buildPrompt(message: message, history: history)

    if #available(iOS 26.0, *) {
      Task {
        do {
          let response = try await appleFoundationProvider.respond(to: prompt)
          result(response)
        } catch {
          result(FlutterError(
            code: "PROCESSING_ERROR",
            message: "Failed to process message: \(error.localizedDescription)",
            details: nil
          ))
        }
      }
    } else {
      result(FlutterError(
        code: "VERSION_NOT_SUPPORTED",
        message: "Apple Foundation requires iOS 26.0 or later",
        details: nil
      ))
    }
  }

  private func buildPrompt(message: String, history: [[String: Any]]) -> String {
    var lines: [String] = []
    for msg in history {
      guard let content = msg["content"] as? String,
            let isUser = msg["isUser"] as? Bool else {
        continue
      }
      let role = isUser ? "User" : "Assistant"
      lines.append("\(role): \(content)")
    }

    let lastIsSameUser = {
      guard let last = history.last,
            let content = last["content"] as? String,
            let isUser = last["isUser"] as? Bool else {
        return false
      }
      return isUser && content == message
    }()

    if !lastIsSameUser {
      lines.append("User: \(message)")
    }

    return lines.joined(separator: "\n")
  }
}

enum AppleFoundationAIProviderError: Error {
  case unavailable
}

final class AppleFoundationAIProvider {
  private let instructions = """
  You are a helpful travel assistant.

  When providing travel recommendations with specific locations (cities, landmarks, restaurants, etc.), include location data at the end of your response in this JSON format:

  ```json
  {
    "locations": [
      {
        "name": "Location Name",
        "lat": 0.0,
        "lng": 0.0,
        "description": "Brief description",
        "day": 1
      }
    ]
  }
  ```

  Important:
  - Only include the JSON block if you mention specific places
  - Use accurate coordinates (latitude/longitude)
  - The "day" field is optional (for multi-day itineraries)
  - Keep your natural response above the JSON block

  Example:
  "I recommend visiting the Eiffel Tower and the Louvre Museum in Paris!

  ```json
  {
    "locations": [
      {"name": "Eiffel Tower", "lat": 48.8584, "lng": 2.2945, "description": "Iconic landmark", "day": 1},
      {"name": "Louvre Museum", "lat": 48.8606, "lng": 2.3376, "description": "World's largest art museum", "day": 1}
    ]
  }
  ```"
  """

  static func isAvailable() -> Bool {
    if #available(iOS 26.0, *) {
      #if canImport(FoundationModels)
      return true
      #else
      return false
      #endif
    }
    return false
  }

  @available(iOS 26.0, *)
  func respond(to prompt: String) async throws -> String {
    #if canImport(FoundationModels)
    let session = LanguageModelSession(instructions: instructions)
    let response = try await session.respond(to: prompt)
    return response.content
    #else
    throw AppleFoundationAIProviderError.unavailable
    #endif
  }
}
