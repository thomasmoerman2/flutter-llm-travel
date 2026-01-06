namespace backend.Services.Llm;
public sealed class OpenAiStreamProvider : ILlmStreamProvider
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IConfiguration _configuration;
    public OpenAiStreamProvider(IHttpClientFactory httpClientFactory, IConfiguration configuration)
    {
        _httpClientFactory = httpClientFactory;
        _configuration = configuration;
    }
    public string Name => "chatgpt";
    public async IAsyncEnumerable<string> StreamAsync(LlmRequest request, CancellationToken cancellationToken)
    {
        var apiKey = _configuration["OpenAiApiKey"];
        if (string.IsNullOrWhiteSpace(apiKey))
        {
            throw new InvalidOperationException("OpenAiApiKey is missing.");
        }
        var model = string.IsNullOrWhiteSpace(request.Model)
            ? _configuration["OpenAiModel"] ?? "gpt-4o"
            : request.Model;
        var messages = new List<object>();
        if (!string.IsNullOrWhiteSpace(request.SystemPrompt))
        {
            messages.Add(new { role = "system", content = request.SystemPrompt });
        }
        messages.Add(new { role = "user", content = request.Prompt });
        var payload = new
        {
            model,
            stream = true,
            messages
        };
        var json = JsonSerializer.Serialize(payload);
        var client = _httpClientFactory.CreateClient("external");
        using var httpRequest = new HttpRequestMessage(HttpMethod.Post, "https://api.openai.com/v1/chat/completions");
        httpRequest.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", apiKey);
        httpRequest.Content = new StringContent(json, Encoding.UTF8, "application/json");
        using var response = await client.SendAsync(httpRequest, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        response.EnsureSuccessStatusCode();
        await foreach (var chunk in ReadSseStreamAsync(await response.Content.ReadAsStreamAsync(cancellationToken), cancellationToken))
        {
            if (chunk == "[DONE]")
            {
                yield break;
            }
            using var document = JsonDocument.Parse(chunk);
            if (!document.RootElement.TryGetProperty("choices", out var choices) || choices.GetArrayLength() == 0)
            {
                continue;
            }
            var choice = choices[0];
            if (!choice.TryGetProperty("delta", out var delta))
            {
                continue;
            }
            if (delta.TryGetProperty("content", out var contentElement))
            {
                var content = contentElement.GetString();
                if (!string.IsNullOrWhiteSpace(content))
                {
                    yield return content;
                }
            }
        }
    }
    private static async IAsyncEnumerable<string> ReadSseStreamAsync(Stream stream, [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        using var reader = new StreamReader(stream);
        while (!reader.EndOfStream && !cancellationToken.IsCancellationRequested)
        {
            var line = await reader.ReadLineAsync(cancellationToken);
            if (string.IsNullOrWhiteSpace(line))
            {
                continue;
            }
            if (!line.StartsWith("data:", StringComparison.Ordinal))
            {
                continue;
            }
            var payload = line.Substring("data:".Length).Trim();
            if (!string.IsNullOrWhiteSpace(payload))
            {
                yield return payload;
            }
        }
    }
}
