// Configure Serilog bootstrap logger for early startup logging
using Microsoft.AspNetCore.DataProtection;

Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .WriteTo.File("logs/log.txt", rollingInterval: RollingInterval.Day)
    .MinimumLevel.Warning()
    .CreateLogger();

var builder = WebApplication.CreateBuilder(args);

// Clear default providers and use Serilog
builder.Logging.ClearProviders();
builder.Logging.AddSerilog(Log.Logger);
builder.Services.AddDataProtection().PersistKeysToFileSystem(new DirectoryInfo("/app/keys"));
builder.Configuration.AddJsonFile("/app/keys/appsettings.Production.json", optional: true, reloadOnChange: true);

// Firebase credentials: support both a JSON file path and a raw JSON string.
// In production, FIREBASE_CREDENTIALS_FILE points to the mounted service account JSON.
// In development, FirebaseCredentials in appsettings.json holds the credentials object.
string? firebaseJson = null;

string? credFilePath = builder.Configuration["FIREBASE_CREDENTIALS_FILE"];
if (!string.IsNullOrWhiteSpace(credFilePath) && File.Exists(credFilePath))
{
    firebaseJson = File.ReadAllText(credFilePath);
    Log.Information("[X] FirebaseCredentials : Loaded from file ({Path})", credFilePath);
}
else
{
    var firebaseConfig = builder.Configuration.GetSection("FirebaseCredentials");
    if (firebaseConfig.Exists() && firebaseConfig.GetChildren().Any())
    {
        firebaseJson = System.Text.Json.JsonSerializer.Serialize(
            firebaseConfig.Get<Dictionary<string, object>>()
        );
        Log.Information("[X] FirebaseCredentials : Loaded from configuration section");
    }
}

if (!string.IsNullOrWhiteSpace(firebaseJson))
{
    try
    {
        FirebaseApp.Create(new AppOptions()
        {
            Credential = GoogleCredential.FromJson(firebaseJson),
        });
        Log.Information("[X] FirebaseCredentials : App initialized");
    }
    catch (Exception ex)
    {
        Log.Error(ex, "Hey buddy, FirebaseConfig_Error!");
    }
}
else
{
    Log.Information("[ ] FirebaseCredentials : null");
}

string? corsEnv = builder.Configuration["CORS"];
string[] corsOrigins = Array.Empty<string>();
if (!string.IsNullOrWhiteSpace(corsEnv))
{
    corsOrigins = corsEnv.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
}
builder.Services.AddCors(options =>
{
    options.AddPolicy("MyCORS", builder =>
    {
        builder.AllowAnyOrigin()
            .WithOrigins("*")
            .WithMethods("GET", "POST", "DELETE")
           .WithHeaders("X-MCT-Header", "Authorization", "Content-Type");
    });
    options.AddPolicy("production", builder =>
    {
        if (corsOrigins.Length == 0)
        {
            builder.AllowAnyOrigin();
        }
        else
        {
            builder.WithOrigins(corsOrigins);
        }

        builder.WithMethods("GET", "POST", "DELETE")
           .WithHeaders("X-MCT-Header", "Authorization", "Content-Type");
    });
});
builder.Services.AddMvc();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo { Title = "Travel", Version = "v1" });
});
builder.Services.AddAuthentication("Firebase")
    .AddScheme<AuthenticationSchemeOptions, FirebaseAuthenticationHandler>("Firebase", options => { });
// Services container
var app = builder.Build();
app.UseCors("MyCORS");
app.UseAuthentication();
app.UseAuthorization();
app.UseSwagger(); // default endpoint is /swagger/v1/swagger.json
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("v1/swagger.json", "Travel"); //UI endpoint is /swagger/index.html
});
app.MapGet("/", () => Results.Ok(new { hello = "Hello, Developer", docs = "API Documentation /swagger/index.html", docsJson = "API Documentation /swagger/v1/swagger.json" })).WithTags("1. Header");
app.MapGroup("/model").GroupAIModels().WithTags("2. AI Models");
app.MapFallback((HttpContext context) =>
{
    return Results.NotFound(new { error = "Not found", status = 404, path = context.Request.Path });
});
app.Run();
