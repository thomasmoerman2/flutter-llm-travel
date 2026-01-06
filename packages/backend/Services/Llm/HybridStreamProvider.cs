namespace backend.Services.Llm;
public sealed class HybridStreamProvider : ILlmStreamProvider
{
    private readonly OpenAiStreamProvider _openAi;
    private readonly GeminiStreamProvider _gemini;
    private readonly IFoundationPromptProvider _foundationPromptProvider;
    public HybridStreamProvider(
        OpenAiStreamProvider openAi,
        GeminiStreamProvider gemini,
        IFoundationPromptProvider foundationPromptProvider)
    {
        _openAi = openAi;
        _gemini = gemini;
        _foundationPromptProvider = foundationPromptProvider;
    }
    public string Name => "hybrid";
    public async IAsyncEnumerable<string> StreamAsync(LlmRequest request, [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        var foundationPrompt = await _foundationPromptProvider.BuildPromptAsync(request.Prompt, cancellationToken);
        var enrichedRequest = request with { Prompt = foundationPrompt };
        var openAiTask = CollectAsync(_openAi, enrichedRequest, cancellationToken);
        var geminiTask = CollectAsync(_gemini, enrichedRequest, cancellationToken);
        await Task.WhenAll(openAiTask, geminiTask);
        var openAiResult = await openAiTask;
        var geminiResult = await geminiTask;
        var best = SelectBest(openAiResult, geminiResult);
        if (!string.IsNullOrWhiteSpace(best))
        {
            yield return best;
        }
    }
    private static async Task<string> CollectAsync(
        ILlmStreamProvider provider,
        LlmRequest request,
        CancellationToken cancellationToken)
    {
        var builder = new StringBuilder();
        await foreach (var chunk in provider.StreamAsync(request, cancellationToken))
        {
            builder.Append(chunk);
        }
        return builder.ToString();
    }
    private static string SelectBest(string first, string second)
    {
        if (string.IsNullOrWhiteSpace(first))
        {
            return second;
        }
        if (string.IsNullOrWhiteSpace(second))
        {
            return first;
        }
        return first.Length >= second.Length ? first : second;
    }
}
