var builder = WebApplication.CreateBuilder(args);
builder.Services.AddMemoryCache();
builder.Services.AddOutputCache(options =>
{
    options.AddBasePolicy(builder => builder.Expire(TimeSpan.FromSeconds(10)).SetVaryByQuery("*"));
    options.AddPolicy("10sec", builder => builder.Expire(TimeSpan.FromSeconds(10)).SetVaryByQuery("*"));
});
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("Fixed", opt =>
    {
        opt.Window = TimeSpan.FromSeconds(3);
        opt.PermitLimit = 3;
    });
});
builder.Services.AddHealthChecks();
builder.Services.AddHealthChecksUI().AddInMemoryStorage();
builder.Services.AddHttpClient("external").AddStandardResilienceHandler(options =>
{
    options.Retry.MaxRetryAttempts = 1;
    options.Retry.ShouldHandle = args =>
    {
        if (args.Outcome.Result is HttpResponseMessage response &&
            response.StatusCode == HttpStatusCode.TooManyRequests)
        {
            return ValueTask.FromResult(false);
        }
        return ValueTask.FromResult(HttpClientResiliencePredicates.IsTransient(args.Outcome));
    };
});
builder.Services.AddSingleton<IFoundationPromptProvider, FoundationPromptProvider>();
builder.Services.AddSingleton<OpenAiStreamProvider>();
builder.Services.AddSingleton<GeminiStreamProvider>();
builder.Services.AddSingleton<HybridStreamProvider>();
builder.Services.AddSingleton<ILlmRequestLimiter, LlmRequestLimiter>();
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo { Title = "My API", Version = "v1" });
});
// Firebase Configuration
string firebaseCredentialsJson = builder.Configuration["FirebaseCredentials"];
if (!string.IsNullOrWhiteSpace(firebaseCredentialsJson))
{
    FirebaseApp.Create(new AppOptions()
    {
        Credential = GoogleCredential.FromJson(firebaseCredentialsJson),
    });
}
else if (builder.Environment.IsDevelopment())
{
    Console.WriteLine("Warning: FirebaseCredentials is not set. Firebase auth will be unavailable in development.");
}
else
{
    throw new InvalidOperationException("Firebase credentials are missing. Set the FirebaseCredentials environment variable.");
}
builder.Services.AddFirebaseAuthentication();
var mongoSettings = builder.Configuration.GetSection("MongoDB");
builder.Services.Configure<DatabaseSettings>(mongoSettings);
builder.Services.AddScoped<IMongoContext, MongoContext>();
builder.Services.AddApiVersioning(options =>
{
    options.ReportApiVersions = true;
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.DefaultApiVersion = new ApiVersion(1, 0);
    options.ApiVersionReader = new HeaderApiVersionReader("api-version");
});
builder.Services.AddCors(options =>
{
    options.AddPolicy("MyCORS", builder =>
    {
        builder.AllowAnyOrigin()
            .WithOrigins("http://localhost:8000")
            .WithMethods("GET", "POST", "DELETE")
           .WithHeaders("X-MCT-Header");
    });
});
builder.Logging.ClearProviders();
// Serilog configuration
var logger = new LoggerConfiguration()
    .MinimumLevel.Override("Microsoft.Extensions.Http.Resilience", LogEventLevel.Warning)
    .MinimumLevel.Override("System.Net.Http.HttpClient", LogEventLevel.Warning)
    .WriteTo.Console()
    .WriteTo.File("logs/log.txt", rollingInterval: RollingInterval.Day)
    .MinimumLevel.Debug()
    .CreateLogger();
// Register Serilog
builder.Logging.AddSerilog(logger);
// Services container
var app = builder.Build();
app.UseOutputCache();
app.UseRateLimiter();
app.UseSwagger(); // default endpoint is /swagger/v1/swagger.json
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("v1/swagger.json", "My API V1"); //UI endpoint is /swagger/index.html
});
app.UseCors("MyCORS");
var versionSet = app.NewApiVersionSet()
.HasApiVersion(1, 0)
.HasApiVersion(2, 0).Build();
// Routes
app.MapSystemRoutes();
app.MapApiRoutes(versionSet);
app.MapControllers();
app.Run();
