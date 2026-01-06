namespace backend.Models;
public class DatabaseSettings
{
    IMongoClient Client { get; }
    IMongoDatabase Database { get; }
    public string ConnectionString { get; set; } = null!;
    public string DatabaseName { get; set; } = null!;
    // Collection names
}
