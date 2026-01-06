namespace backend.Services.Llm;
public sealed class GeminiStreamProvider : ILlmStreamProvider
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IConfiguration _configuration;
    public GeminiStreamProvider(IHttpClientFactory httpClientFactory, IConfiguration configuration)
    {
        _httpClientFactory = httpClientFactory;
        _configuration = configuration;
    }
    public string Name => "gemini";
    public async IAsyncEnumerable<string> StreamAsync(
        LlmRequest request,
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        var apiKey = _configuration["GeminiApiKey"];
        if (string.IsNullOrWhiteSpace(apiKey))
        {
            throw new InvalidOperationException("GeminiApiKey is missing.");
        }
        var model = string.IsNullOrWhiteSpace(request.Model)
            ? _configuration["GeminiModel"] ?? "gemini-2.0-flash"
            : request.Model;
        var contents = new List<object>();
        if (!string.IsNullOrWhiteSpace(request.SystemPrompt))
        {
            contents.Add(new
            {
                role = "user",
                parts = new[] { new { text = $"System: {request.SystemPrompt}" } }
            });
        }
        contents.Add(new
        {
            role = "user",
            parts = new[] { new { text = request.Prompt } }
        });
        var payload = new
        {
            contents
        };
        var json = JsonSerializer.Serialize(payload);
        var endpoint = $"https://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent?key={apiKey}";
        var client = _httpClientFactory.CreateClient("external");
        using var httpRequest = new HttpRequestMessage(HttpMethod.Post, endpoint);
        httpRequest.Content = new StringContent(json, Encoding.UTF8, "application/json");
        using var response = await client.SendAsync(httpRequest, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        response.EnsureSuccessStatusCode();
        await foreach (var chunk in ReadJsonStreamAsync(await response.Content.ReadAsStreamAsync(cancellationToken), cancellationToken))
        {
            using var document = JsonDocument.Parse(chunk);
            if (!document.RootElement.TryGetProperty("candidates", out var candidates) || candidates.GetArrayLength() == 0)
            {
                continue;
            }
            var candidate = candidates[0];
            if (!candidate.TryGetProperty("content", out var content))
            {
                continue;
            }
            if (!content.TryGetProperty("parts", out var parts) || parts.GetArrayLength() == 0)
            {
                continue;
            }
            var text = parts[0].GetProperty("text").GetString();
            if (!string.IsNullOrWhiteSpace(text))
            {
                yield return text;
            }
        }
    }
    private static async IAsyncEnumerable<string> ReadJsonStreamAsync(Stream stream, [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        using var reader = new StreamReader(stream);
        while (!reader.EndOfStream && !cancellationToken.IsCancellationRequested)
        {
            var line = await reader.ReadLineAsync(cancellationToken);
            if (!string.IsNullOrWhiteSpace(line))
            {
                yield return line;
            }
        }
    }
}
