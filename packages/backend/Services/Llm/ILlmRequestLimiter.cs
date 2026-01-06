namespace backend.Services.Llm;
public interface ILlmRequestLimiter
{
    bool TryAcquire(string key, out TimeSpan retryAfter);
}
