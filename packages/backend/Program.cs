// Configure Serilog bootstrap logger for early startup logging
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .WriteTo.File("logs/log.txt", rollingInterval: RollingInterval.Day)
    .MinimumLevel.Debug()
    .CreateLogger();

var builder = WebApplication.CreateBuilder(args);

// Clear default providers and use Serilog
builder.Logging.ClearProviders();
builder.Logging.AddSerilog(Log.Logger);

var firebaseConfig = builder.Configuration.GetSection("FirebaseCredentials");
if (firebaseConfig.Exists() && firebaseConfig.GetChildren().Any()) // FirebaseConfig
{
    Log.Information("[X] FirebaseCredentials : Found");
    try
    {
        // Serialize the configuration section to JSON
        string json = System.Text.Json.JsonSerializer.Serialize(
            firebaseConfig.Get<Dictionary<string, object>>()
        );
        // Initialize Firebase with credentials
        FirebaseApp.Create(new AppOptions()
        {
            Credential = GoogleCredential.FromJson(json),
        });
    }
    catch (Exception ex)
    {
        // Log the error but don't crash the application
        Log.Error(ex, "Hey buddy, FirebaseConfig_Error!");
    }
}
else
{
    // For development: Use local Firebase credentials
    Log.Information("[ ] FirebaseCredentials : null");
}

string corsEnv = builder.Configuration["CORS"];
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
        builder.AllowAnyOrigin()
            .WithOrigins(corsEnv)
            .WithMethods("GET", "POST", "DELETE")
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
