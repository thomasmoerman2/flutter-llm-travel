namespace backend.Routes;
public static class ApiRoutes
{
    public static void MapApiRoutes(this WebApplication app, Asp.Versioning.Builder.ApiVersionSet versionSet)
    {
        var api = app.MapGroup("/api").WithTags("API");
        var v1 = api.MapGroup("/v1")
            .WithTags("v1")
            .WithApiVersionSet(versionSet)
            .MapToApiVersion(1.0);
        v1.MapV1Routes();
        var v2 = api.MapGroup("/v2")
            .WithTags("v2")
            .WithApiVersionSet(versionSet)
            .MapToApiVersion(2.0);
        v2.MapV2Routes();
    }
    private static RouteGroupBuilder MapV1Routes(this RouteGroupBuilder group)
    {
        group.MapGet("/data", (ILoggerFactory loggerFactory) =>
        {
            var logger = loggerFactory.CreateLogger("ApiV1");
            try
            {
                logger.LogInformation("Returning list of <something> {<something>}", "");
                return Results.Ok();
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "An error occurred while processing request");
                return Results.Problem("An error occurred while processing request");
            }
        })
        .WithName("GetDataV1");
        return group;
    }
    private static RouteGroupBuilder MapV2Routes(this RouteGroupBuilder group)
    {
        group.MapGet("/data", () => Results.Ok())
            .WithName("GetDataV2");
        return group;
    }
}
