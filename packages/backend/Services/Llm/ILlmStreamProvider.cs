namespace backend.Services.Llm;
public interface ILlmStreamProvider
{
    string Name { get; }
    IAsyncEnumerable<string> StreamAsync(LlmRequest request, CancellationToken cancellationToken);
}
