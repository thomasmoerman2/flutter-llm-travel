namespace backend.Services.Llm;
public sealed record LlmRequest(
    string Prompt,
    string? Model,
    string? SystemPrompt,
    string SessionId);
