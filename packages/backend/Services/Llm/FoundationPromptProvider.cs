namespace backend.Services.Llm;
public interface IFoundationPromptProvider
{
    Task<string> BuildPromptAsync(string prompt, CancellationToken cancellationToken);
}
public sealed class FoundationPromptProvider : IFoundationPromptProvider
{
    private readonly IConfiguration _configuration;
    public FoundationPromptProvider(IConfiguration configuration)
    {
        _configuration = configuration;
    }
    public Task<string> BuildPromptAsync(string prompt, CancellationToken cancellationToken)
    {
        var prefix = _configuration["FoundationPrompt"];
        if (string.IsNullOrWhiteSpace(prefix))
        {
            return Task.FromResult(prompt);
        }
        return Task.FromResult($"{prefix}\n{prompt}");
    }
}
