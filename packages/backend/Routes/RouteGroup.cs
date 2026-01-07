public static class MyGroups
{
    public static RouteGroupBuilder GroupAIModels(this RouteGroupBuilder endpoint)
    {
        endpoint.MapGet("/", () =>
        {
            // Create an array of objects
            AIModelConfig[] dataList = [
                new AIModelConfig { Endpoints = "/gpt", Provider = "OpenAI", Model = "gpt-4o-mini" },
                new AIModelConfig { Endpoints = "/gemini", Provider = "Google", Model = "gemini-pro" },
                new AIModelConfig { Endpoints = "/hybrid", Provider = "Mixed", Model = "Apple Foundation / gpt-4o-mini / gemini-pro" }
            ];

            return Results.Ok(new { head = "Here a list of AI models on this project", data = dataList });
        });
        endpoint.MapPost("/gpt", async (HttpContext context, IConfiguration configuration) =>
        {
            try
            {
                // Read and parse request body
                string message = null;
                try
                {
                    var body = await context.Request.ReadFromJsonAsync<GptRequest>();
                    message = body?.Message;
                }
                catch (JsonException ex)
                {
                    Log.Error(ex, "Failed to parse JSON request body");
                    return Results.BadRequest(new { error = "Invalid JSON format. Expected: { \"message\": \"your message\" }" });
                }

                Log.Information("GPT endpoint called with message length: {MessageLength}", message?.Length ?? 0);

                // Validate input
                if (string.IsNullOrWhiteSpace(message))
                {
                    Log.Warning("GPT endpoint received empty or null message");
                    return Results.BadRequest(new { error = "Message cannot be empty. Expected: { \"message\": \"your message\" }" });
                }

                // Check API key from configuration (appsettings)
                var apiKey = configuration["OpenAIAPIKey"];
                if (string.IsNullOrEmpty(apiKey))
                {
                    Log.Error("OpenAI API key not configured in appsettings.json");
                    return Results.Problem("OpenAI API key not configured", statusCode: 500);
                }

                Log.Debug("Creating OpenAI client");
                var client = new OpenAIClient(apiKey);

                var messages = new List<ChatMessage>
                {
                    new SystemChatMessage("You are a helpful assistant."),
                    new UserChatMessage(message)
                };

                Log.Information("Sending request to OpenAI API");
                var response = await client.GetChatClient("gpt-4o-mini")
                    .CompleteChatAsync(messages);

                Log.Information("Successfully received response from OpenAI API");
                return Results.Ok(new { response = response.Value.Content[0].Text });
            }
            catch (ArgumentException ex)
            {
                Log.Error(ex, "Invalid argument provided to GPT endpoint");
                return Results.BadRequest(new { error = "Invalid request parameters", details = ex.Message });
            }
            catch (HttpRequestException ex)
            {
                Log.Error(ex, "Network error while calling OpenAI API");
                return Results.Problem("Failed to connect to OpenAI service", statusCode: 503);
            }
            catch (TaskCanceledException ex)
            {
                Log.Error(ex, "Request to OpenAI API timed out");
                return Results.Problem("Request timed out", statusCode: 504);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Unexpected error in GPT endpoint: {ErrorMessage}", ex.Message);
                return Results.Problem("An unexpected error occurred while processing your request", statusCode: 500);
            }
        });
        endpoint.MapPost("/gemini", async (HttpContext context, IConfiguration configuration) =>
        {
            try
            {
                // Read and parse request body
                string message = null;
                try
                {
                    var body = await context.Request.ReadFromJsonAsync<GptRequest>();
                    message = body?.Message;
                }
                catch (JsonException ex)
                {
                    Log.Error(ex, "Failed to parse JSON request body");
                    return Results.BadRequest(new { error = "Invalid JSON format. Expected: { \"message\": \"your message\" }" });
                }

                Log.Information("Gemini endpoint called with message length: {MessageLength}", message?.Length ?? 0);

                // Validate input
                if (string.IsNullOrWhiteSpace(message))
                {
                    Log.Warning("Gemini endpoint received empty or null message");
                    return Results.BadRequest(new { error = "Message cannot be empty. Expected: { \"message\": \"your message\" }" });
                }

                // Check API key from configuration (appsettings)
                var apiKey = configuration["GeminiAPIKey"];
                if (string.IsNullOrEmpty(apiKey))
                {
                    Log.Error("Gemini API key not configured in appsettings.json");
                    return Results.Problem("Gemini API key not configured", statusCode: 500);
                }

                Log.Debug("Creating Gemini client");
                var client = new Client(apiKey: apiKey);

                Log.Information("Sending request to Gemini API");
                var response = await client.Models.GenerateContentAsync(
                    model: "gemini-2.5-flash",
                    contents: message
                );

                Log.Information("Successfully received response from Gemini API");
                return Results.Ok(new { response = response });
            }
            catch (ArgumentException ex)
            {
                Log.Error(ex, "Invalid argument provided to Gemini endpoint");
                return Results.BadRequest(new { error = "Invalid request parameters", details = ex.Message });
            }
            catch (HttpRequestException ex)
            {
                Log.Error(ex, "Network error while calling Gemini API");
                return Results.Problem("Failed to connect to Gemini service", statusCode: 503);
            }
            catch (TaskCanceledException ex)
            {
                Log.Error(ex, "Request to Gemini API timed out");
                return Results.Problem("Request timed out", statusCode: 504);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Unexpected error in Gemini endpoint: {ErrorMessage}", ex.Message);
                return Results.Problem("An unexpected error occurred while processing your request", statusCode: 500);
            }
        });
        endpoint.MapPost("/hybrid", () => { });
        return endpoint;
    }
}


public class AIModelConfig
{
    public string Endpoints { get; set; }
    public string Provider { get; set; }
    public string Model { get; set; }
}

public class GptRequest
{
    public string Message { get; set; }
}