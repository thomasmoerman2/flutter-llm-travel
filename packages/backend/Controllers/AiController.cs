namespace backend.Controllers;

[ApiController]
[Route("api/ai")]
public sealed class AiController : ControllerBase
{
    private readonly OpenAiStreamProvider _openAi;
    private readonly GeminiStreamProvider _gemini;
    private readonly HybridStreamProvider _hybrid;
    private readonly ILlmRequestLimiter _requestLimiter;
    private readonly ILogger<AiController> _logger;

    public AiController(
        OpenAiStreamProvider openAi,
        GeminiStreamProvider gemini,
        HybridStreamProvider hybrid,
        ILlmRequestLimiter requestLimiter,
        ILogger<AiController> logger)
    {
        _openAi = openAi;
        _gemini = gemini;
        _hybrid = hybrid;
        _requestLimiter = requestLimiter;
        _logger = logger;
    }

    [HttpPost("chatgpt")]
    public Task<IActionResult> ChatGpt([FromBody] LlmApiRequest request, CancellationToken cancellationToken)
    {
        return HandleAsync(_openAi, request, cancellationToken);
    }

    [HttpPost("gemini")]
    public Task<IActionResult> Gemini([FromBody] LlmApiRequest request, CancellationToken cancellationToken)
    {
        return HandleAsync(_gemini, request, cancellationToken);
    }

    [HttpPost("hybrid")]
    public Task<IActionResult> Hybrid([FromBody] LlmApiRequest request, CancellationToken cancellationToken)
    {
        return HandleAsync(_hybrid, request, cancellationToken);
    }

    private async Task<IActionResult> HandleAsync(
        ILlmStreamProvider provider,
        LlmApiRequest request,
        CancellationToken cancellationToken)
    {
        if (request is null || string.IsNullOrWhiteSpace(request.Prompt))
        {
            return BadRequest(new { error = "Prompt is required." });
        }

        var sessionId = string.IsNullOrWhiteSpace(request.SessionId)
            ? Guid.NewGuid().ToString("N")
            : request.SessionId;

        var userId = ResolveUserId();
        if (!_requestLimiter.TryAcquire($"{userId}:{sessionId}", out var retryAfter))
        {
            return StatusCode(
                StatusCodes.Status429TooManyRequests,
                new { error = "Rate limited.", retryAfterMs = (int)Math.Ceiling(retryAfter.TotalMilliseconds) });
        }

        var llmRequest = new LlmRequest(request.Prompt, request.Model, request.SystemPrompt, sessionId);

        try
        {
            _logger.LogInformation(
                "LLM API request received. Provider: {Provider} SessionId: {SessionId} UserId: {UserId} Model: {Model}",
                provider.Name,
                sessionId,
                userId,
                request.Model ?? "default");

            var responseText = await CollectAsync(provider, llmRequest, cancellationToken);
            return Ok(new LlmApiResponse(provider.Name, sessionId, responseText));
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "LLM API call failed. Provider: {Provider} SessionId: {SessionId}", provider.Name, sessionId);
            return StatusCode(
                StatusCodes.Status502BadGateway,
                new { error = ex.Message, provider = provider.Name, sessionId });
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

    private string ResolveUserId()
    {
        return User?.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? User?.FindFirst("uid")?.Value
            ?? "anonymous";
    }
}

public sealed record LlmApiRequest(
    string Prompt,
    string? Model,
    string? SystemPrompt,
    string? SessionId);

public sealed record LlmApiResponse(
    string Provider,
    string SessionId,
    string Content);
