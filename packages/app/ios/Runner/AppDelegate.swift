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
  You are a helpful travel and navigation assistant. When users ask for directions or travel advice:
  1. Provide clear, step-by-step directions starting from their current location
  2. List interesting points of interest and things to visit at the destination
  3. Include practical travel tips like estimated time, parking, and best times to visit
  4. Format responses with clear sections and bullet points for easy reading
  5. Be concise but informative
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
