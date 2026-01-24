import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../services/ai/ai_service_factory.dart';
import '../services/ai/apple_intelligence_service.dart';
import '../services/theme_color.dart';

/// Result from a single AI model comparison
class CompareResult {
  final String modelName;
  final String response;
  final bool isError;
  final IconData icon;

  CompareResult({
    required this.modelName,
    required this.response,
    this.isError = false,
    required this.icon,
  });
}

/// Compare page that shows 3 AI results side by side
class ComparePageContent extends StatefulWidget {
  final void Function(String prompt, String selectedResponse, String modelName)?
  onSelectResult;

  const ComparePageContent({super.key, this.onSelectResult});

  @override
  State<ComparePageContent> createState() => ComparePageContentState();
}

class ComparePageContentState extends State<ComparePageContent> {
  final TextEditingController _textController = TextEditingController();

  bool _isAppleIntelligenceAvailable = false;
  bool _isCheckingAvailability = true;
  bool _isComparing = false;
  String? _currentPrompt;
  List<CompareResult> _results = [];
  Map<String, bool> _loadingStates = {};

  @override
  void initState() {
    super.initState();
    _checkAppleIntelligenceAvailability();
  }

  Future<void> _checkAppleIntelligenceAvailability() async {
    setState(() {
      _isCheckingAvailability = true;
    });

    try {
      if (Platform.isIOS) {
        final service = AppleIntelligenceService();
        final available = await service.isAvailable();
        await service.dispose();

        if (mounted) {
          setState(() {
            _isAppleIntelligenceAvailable = available;
            _isCheckingAvailability = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isAppleIntelligenceAvailable = false;
            _isCheckingAvailability = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAppleIntelligenceAvailable = false;
          _isCheckingAvailability = false;
        });
      }
    }
  }

  IconData _getModelIcon(String model) {
    switch (model) {
      case 'ChatGPT':
        return LucideIcons.messageSquare;
      case 'Gemini':
        return LucideIcons.sparkles;
      case 'Apple Intelligence':
        return LucideIcons.cpu;
      case 'Hybrid':
        return LucideIcons.zap;
      default:
        return LucideIcons.bot;
    }
  }

  List<String> _getModelsToCompare() {
    if (_isAppleIntelligenceAvailable) {
      return ['ChatGPT', 'Gemini', 'Apple Intelligence'];
    } else {
      // Without Apple Intelligence, compare ChatGPT, Gemini, and Hybrid
      return ['ChatGPT', 'Gemini', 'Hybrid'];
    }
  }

  Future<void> _runComparison() async {
    final prompt = _textController.text.trim();
    if (prompt.isEmpty || _isComparing) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginRequired();
      return;
    }

    setState(() {
      _isComparing = true;
      _currentPrompt = prompt;
      _results = [];
      _loadingStates = {};
    });

    // Clear the input field
    _textController.clear();

    final models = _getModelsToCompare();

    // Initialize loading states
    for (final model in models) {
      _loadingStates[model] = true;
    }
    setState(() {});

    // Run all models in parallel
    final futures = models.map((model) => _queryModel(model, prompt, user.uid));
    await Future.wait(futures);

    if (mounted) {
      setState(() {
        _isComparing = false;
      });
    }
  }

  Future<void> _queryModel(
    String modelName,
    String prompt,
    String userId,
  ) async {
    try {
      final service = AIServiceFactory.createService(modelName);
      await service.initialize();

      final responseBuffer = StringBuffer();

      await for (final chunk in service.sendMessage(prompt, [], userId)) {
        responseBuffer.write(chunk);
      }

      await service.dispose();

      if (mounted) {
        setState(() {
          _loadingStates[modelName] = false;
          _results.add(
            CompareResult(
              modelName: modelName,
              response: responseBuffer.toString(),
              icon: _getModelIcon(modelName),
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingStates[modelName] = false;
          _results.add(
            CompareResult(
              modelName: modelName,
              response: 'Error: ${e.toString()}',
              isError: true,
              icon: _getModelIcon(modelName),
            ),
          );
        });
      }
    }
  }

  void _selectResult(CompareResult result) {
    if (result.isError || _currentPrompt == null) return;

    widget.onSelectResult?.call(
      _currentPrompt!,
      result.response,
      result.modelName,
    );
  }

  void _showLoginRequired() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Login Required'),
        content: const Text('Please log in to compare AI responses.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAvailability) {
      return const Center(child: CupertinoActivityIndicator());
    }

    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Column(
        children: [
          // Results or empty state
          Expanded(
            child: _currentPrompt == null
                ? _buildEmptyState()
                : _buildResultsView(),
          ),

          // Input field
          SafeArea(
            top: false,
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: ThemeColor.background,
                border: Border(
                  top: BorderSide(
                    color: ThemeColor.textSecondary.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.gitCompareArrows,
                        size: 14,
                        color: ThemeColor.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isAppleIntelligenceAvailable
                            ? 'Compare: ChatGPT, Gemini, Apple Intelligence'
                            : 'Compare: ChatGPT, Gemini, Hybrid',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ThemeColor.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: _textController,
                          placeholder: 'Enter your prompt to compare...',
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _runComparison(),
                          enabled: !_isComparing,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _isComparing
                                ? ThemeColor.inputBackground.withOpacity(0.5)
                                : ThemeColor.inputBackground,
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _isComparing ? null : _runComparison,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _isComparing
                                ? ThemeColor.textSecondary.withOpacity(0.3)
                                : ThemeColor.primary,
                            shape: BoxShape.circle,
                          ),
                          child: _isComparing
                              ? const Center(
                                  child: CupertinoActivityIndicator(
                                    color: ThemeColor.background,
                                  ),
                                )
                              : const Icon(
                                  LucideIcons.send,
                                  size: 20,
                                  color: ThemeColor.textPrimary,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.gitCompareArrows,
              size: 64,
              color: ThemeColor.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'Compare AI Responses',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: ThemeColor.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isAppleIntelligenceAvailable
                  ? 'Enter a prompt to compare responses from ChatGPT, Gemini, and Apple Intelligence'
                  : 'Enter a prompt to compare responses from ChatGPT, Gemini, and Hybrid',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: ThemeColor.textSecondary,
              ),
            ),
            if (_isAppleIntelligenceAvailable) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ThemeColor.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.cpu, size: 14, color: ThemeColor.primary),
                    SizedBox(width: 6),
                    Text(
                      'Apple Intelligence Available',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ThemeColor.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    final models = _getModelsToCompare();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prompt display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThemeColor.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.messageCircle,
                  size: 16,
                  color: ThemeColor.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentPrompt ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: ThemeColor.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Results
          ...models.map((model) {
            final isLoading = _loadingStates[model] ?? false;
            final result = _results
                .where((r) => r.modelName == model)
                .firstOrNull;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CompareResultCard(
                modelName: model,
                icon: _getModelIcon(model),
                isLoading: isLoading,
                result: result,
                onSelect: result != null && !result.isError
                    ? () => _selectResult(result)
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Clean markdown response by removing JSON code blocks meant for location parsing
String _cleanMarkdownResponse(String response) {
  // Remove JSON code blocks that contain location data
  final jsonBlockPattern = RegExp(
    r'```json\s*\{[\s\S]*?"locations"[\s\S]*?\}\s*```',
    multiLine: true,
  );
  return response.replaceAll(jsonBlockPattern, '').trim();
}

class _CompareResultCard extends StatelessWidget {
  final String modelName;
  final IconData icon;
  final bool isLoading;
  final CompareResult? result;
  final VoidCallback? onSelect;

  const _CompareResultCard({
    required this.modelName,
    required this.icon,
    required this.isLoading,
    this.result,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: result?.isError == true
              ? const Color(0xFFEF5350)
              : ThemeColor.divider,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThemeColor.background.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: ThemeColor.textPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    modelName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ThemeColor.textPrimary,
                    ),
                  ),
                ),
                if (isLoading)
                  const CupertinoActivityIndicator(radius: 8)
                else if (result != null && !result!.isError)
                  GestureDetector(
                    onTap: onSelect,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ThemeColor.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Select',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ThemeColor.textPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: isLoading
                ? const Row(
                    children: [
                      CupertinoActivityIndicator(radius: 8),
                      SizedBox(width: 8),
                      Text(
                        'Generating response...',
                        style: TextStyle(
                          fontSize: 14,
                          color: ThemeColor.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  )
                : result != null
                ? result!.isError
                      ? Text(
                          result!.response,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFEF5350),
                          ),
                        )
                      : MarkdownBody(
                          data: _cleanMarkdownResponse(result!.response),
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              fontSize: 14,
                              color: ThemeColor.textPrimary,
                              height: 1.4,
                            ),
                            strong: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: ThemeColor.textPrimary,
                            ),
                            em: const TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: ThemeColor.textPrimary,
                            ),
                            code: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              backgroundColor: ThemeColor.background,
                              color: ThemeColor.textPrimary,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: ThemeColor.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            h1: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: ThemeColor.textPrimary,
                            ),
                            h2: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ThemeColor.textPrimary,
                            ),
                            h3: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: ThemeColor.textPrimary,
                            ),
                            listBullet: const TextStyle(
                              fontSize: 14,
                              color: ThemeColor.textPrimary,
                            ),
                          ),
                        )
                : const Text(
                    'Waiting...',
                    style: TextStyle(
                      fontSize: 14,
                      color: ThemeColor.textSecondary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
