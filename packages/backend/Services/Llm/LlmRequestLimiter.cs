namespace backend.Services.Llm;
public sealed class LlmRequestLimiter : ILlmRequestLimiter
{
    private readonly ConcurrentDictionary<string, DateTimeOffset> _lastRequests = new();
    private readonly TimeSpan _minInterval;
    public LlmRequestLimiter(IConfiguration configuration)
    {
        var intervalMs = configuration.GetValue<int?>("LlmMinRequestIntervalMs") ?? 1500;
        _minInterval = TimeSpan.FromMilliseconds(Math.Max(intervalMs, 0));
    }
    public bool TryAcquire(string key, out TimeSpan retryAfter)
    {
        if (_minInterval <= TimeSpan.Zero)
        {
            retryAfter = TimeSpan.Zero;
            return true;
        }
        var now = DateTimeOffset.UtcNow;
        if (!_lastRequests.TryGetValue(key, out var lastRequest))
        {
            _lastRequests[key] = now;
            retryAfter = TimeSpan.Zero;
            return true;
        }
        var elapsed = now - lastRequest;
        if (elapsed < _minInterval)
        {
            retryAfter = _minInterval - elapsed;
            return false;
        }
        _lastRequests[key] = now;
        retryAfter = TimeSpan.Zero;
        return true;
    }
}
