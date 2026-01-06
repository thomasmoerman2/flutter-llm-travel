namespace backend.Routes;

public static class AiRoutes
{
    public static void MapAiRoutes(this WebApplication app)
    {
        var ai = app.MapGroup("/api/ai").WithTags("AI");

        ai.MapPost("/chatgpt", async (
            LlmApiRequest request,
            OpenAiStreamProvider provider,
            ILlmRequestLimiter limiter,
            ILoggerFactory loggerFactory,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var logger = loggerFactory.CreateLogger("AiRoutes");
            return await HandleAsync(provider, request, limiter, logger, context, cancellationToken);
        });

        ai.MapPost("/gemini", async (
            LlmApiRequest request,
            GeminiStreamProvider provider,
            ILlmRequestLimiter limiter,
            ILoggerFactory loggerFactory,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var logger = loggerFactory.CreateLogger("AiRoutes");
            return await HandleAsync(provider, request, limiter, logger, context, cancellationToken);
        });

        ai.MapPost("/hybrid", async (
            LlmApiRequest request,
            HybridStreamProvider provider,
            ILlmRequestLimiter limiter,
            ILoggerFactory loggerFactory,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var logger = loggerFactory.CreateLogger("AiRoutes");
            return await HandleAsync(provider, request, limiter, logger, context, cancellationToken);
        });
    }

    private static async Task<IResult> HandleAsync(
        ILlmStreamProvider provider,
        LlmApiRequest request,
        ILlmRequestLimiter limiter,
        Microsoft.Extensions.Logging.ILogger logger,
        HttpContext context,
        CancellationToken cancellationToken)
    {
        if (request is null || string.IsNullOrWhiteSpace(request.Prompt))
        {
            return Results.BadRequest(new { error = "Prompt is required." });
        }

        var sessionId = string.IsNullOrWhiteSpace(request.SessionId)
            ? Guid.NewGuid().ToString("N")
            : request.SessionId;

        var userId = ResolveUserId(context);
        if (!limiter.TryAcquire($"{userId}:{sessionId}", out var retryAfter))
        {
            return Results.Json(
                new { error = "Rate limited.", retryAfterMs = (int)Math.Ceiling(retryAfter.TotalMilliseconds) },
                statusCode: StatusCodes.Status429TooManyRequests);
        }

        var llmRequest = new LlmRequest(request.Prompt, request.Model, request.SystemPrompt, sessionId);

        try
        {
            logger.LogInformation(
                "LLM API request received. Provider: {Provider} SessionId: {SessionId} UserId: {UserId} Model: {Model}",
                provider.Name,
                sessionId,
                userId,
                request.Model ?? "default");

            var responseText = await CollectAsync(provider, llmRequest, cancellationToken);
            return Results.Ok(new LlmApiResponse(provider.Name, sessionId, responseText));
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "LLM API call failed. Provider: {Provider} SessionId: {SessionId}", provider.Name, sessionId);
            return Results.Json(
                new { error = ex.Message, provider = provider.Name, sessionId },
                statusCode: StatusCodes.Status502BadGateway);
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

    private static string ResolveUserId(HttpContext context)
    {
        return context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? context.User?.FindFirst("uid")?.Value
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
