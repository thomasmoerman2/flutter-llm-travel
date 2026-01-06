namespace backend.Context;
public interface IMongoContext
{
    Task TestConnection();
    IMongoClient Client { get; }
    IMongoDatabase Database { get; }
    // DbSet properties
}
public class MongoContext : IMongoContext
{
    private readonly MongoClient _client;
    private readonly IMongoDatabase _database;
    private readonly DatabaseSettings _settings;
    public IMongoClient Client
    {
        get
        {
            return _client;
        }
    }
    public IMongoDatabase Database => _database;
    public MongoContext(IOptions<DatabaseSettings> dbOptions)
    {
        _settings = dbOptions.Value;
        _client = new MongoClient(_settings.ConnectionString);
        _database = _client.GetDatabase(_settings.DatabaseName);
    }
    public async Task TestConnection()
    {
        try
        {
            await _client.ListDatabaseNames().FirstAsync();
            Console.WriteLine("MongoDB connection successful!");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"MongoDB connection failed: {ex.Message}");
            throw;
        }
    }
    // Mongo Config Collection
}
