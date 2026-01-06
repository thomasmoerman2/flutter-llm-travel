namespace backend.Routes;
public static class SystemRoutes
{
    public static void MapSystemRoutes(this WebApplication app)
    {
        app.MapGet("/", () => "Hello World!")
            .WithTags("System");
        app.MapHealthChecks("/health", new HealthCheckOptions
        {
            ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
        });
        app.MapHealthChecksUI(options =>
        {
            options.UIPath = "/health-ui";
            options.ApiPath = "/health-ui-api";
        });
        app.MapFallback((HttpContext context) =>
        {
            return Results.NotFound(new { error = "Not found", status = 404, path = context.Request.Path });
        });
    }
}
