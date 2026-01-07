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

                var systemPrompt = @"You are a travel planning assistant. When users ask for travel recommendations, places, routes, or itineraries:

1. Provide a helpful summary or explanation in natural language.
2. Include a JSON code block with location data in this format:

```json
{
  ""locations"": [
    {
      ""name"": ""Location Name"",
      ""lat"": 12.3456,
      ""lng"": -98.7654,
      ""description"": ""Brief description"",
      ""day"": 1
    }
  ],
  ""route"": {
    ""type"": ""driving""
  }
}
```

Required fields: name, lat, lng
Optional fields: description, day (for multi-day itineraries)
Route types: driving, walking, cycling (include route only if the user asks for directions or a route)

Always provide accurate coordinates. If the user's request is not travel-related, respond normally without JSON.";

                var messages = new List<ChatMessage>
                {
                    new SystemChatMessage(systemPrompt),
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

                var systemPrompt = @"You are a travel planning assistant. When users ask for travel recommendations, places, routes, or itineraries:

1. Provide a helpful summary or explanation in natural language.
2. Include a JSON code block with location data in this format:

```json
{
  ""locations"": [
    {
      ""name"": ""Location Name"",
      ""lat"": 12.3456,
      ""lng"": -98.7654,
      ""description"": ""Brief description"",
      ""day"": 1
    }
  ],
  ""route"": {
    ""type"": ""driving""
  }
}
```

Required fields: name, lat, lng
Optional fields: description, day (for multi-day itineraries)
Route types: driving, walking, cycling (include route only if the user asks for directions or a route)

Always provide accurate coordinates. If the user's request is not travel-related, respond normally without JSON.";

                var fullPrompt = $"{systemPrompt}\n\nUser request: {message}";

                Log.Information("Sending request to Gemini API");
                var response = await client.Models.GenerateContentAsync(
                    model: "gemini-2.5-flash",
                    contents: fullPrompt
                );

                Log.Information("Successfully received response from Gemini API");
                var responseText = response.Candidates[0].Content.Parts[0].Text;
                return Results.Ok(new { response = responseText });
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
        endpoint.MapPost("/hybrid", async (HttpContext context, IConfiguration configuration) =>
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

                Log.Information("Hybrid endpoint called with message length: {MessageLength}", message?.Length ?? 0);

                // Validate input
                if (string.IsNullOrWhiteSpace(message))
                {
                    Log.Warning("Hybrid endpoint received empty or null message");
                    return Results.BadRequest(new { error = "Message cannot be empty. Expected: { \"message\": \"your message\" }" });
                }

                // Check both API keys
                var openAiKey = configuration["OpenAIAPIKey"];
                var geminiKey = configuration["GeminiAPIKey"];

                if (string.IsNullOrEmpty(openAiKey))
                {
                    Log.Error("OpenAI API key not configured in appsettings.json");
                    return Results.Problem("OpenAI API key not configured", statusCode: 500);
                }

                if (string.IsNullOrEmpty(geminiKey))
                {
                    Log.Error("Gemini API key not configured in appsettings.json");
                    return Results.Problem("Gemini API key not configured", statusCode: 500);
                }

                // Stage 1: Send to ChatGPT
                Log.Information("Stage 1: Sending request to OpenAI API");
                var openAiClient = new OpenAIClient(openAiKey);

                var systemPrompt = @"You are a travel planning assistant. When users ask for travel recommendations, places, routes, or itineraries:

1. Provide a helpful summary or explanation in natural language.
2. Include a JSON code block with location data in this format:

```json
{
  ""locations"": [
    {
      ""name"": ""Location Name"",
      ""lat"": 12.3456,
      ""lng"": -98.7654,
      ""description"": ""Brief description"",
      ""day"": 1
    }
  ],
  ""route"": {
    ""type"": ""driving""
  }
}
```

Required fields: name, lat, lng
Optional fields: description, day (for multi-day itineraries)
Route types: driving, walking, cycling (include route only if the user asks for directions or a route)

Always provide accurate coordinates. If the user's request is not travel-related, respond normally without JSON.";

                var gptMessages = new List<ChatMessage>
                {
                    new SystemChatMessage(systemPrompt),
                    new UserChatMessage(message)
                };

                var gptResponse = await openAiClient.GetChatClient("gpt-4o-mini")
                    .CompleteChatAsync(gptMessages);

                var gptResult = gptResponse.Value.Content[0].Text;
                Log.Information("Stage 1 complete: Received response from OpenAI (length: {Length})", gptResult.Length);

                // Stage 2: Send GPT result to Gemini for refinement
                Log.Information("Stage 2: Sending GPT result to Gemini API for refinement");
                var geminiClient = new Client(apiKey: geminiKey);

                var geminiSystemPrompt = @"You are a travel planning refinement assistant. You receive travel recommendations from another AI and your job is to:

1. Review and enhance the recommendations
2. Verify or correct any location coordinates if needed
3. Add additional insights or local tips
4. Maintain the JSON structure if present
5. Improve the overall quality and accuracy of the response

Keep the same format and structure, just enhance the content.";

                var geminiPrompt = $"{geminiSystemPrompt}\n\nOriginal recommendations:\n{gptResult}\n\nPlease review, enhance, and return improved recommendations:";

                var geminiResponse = await geminiClient.Models.GenerateContentAsync(
                    model: "gemini-2.5-flash",
                    contents: geminiPrompt
                );

                Log.Information("Stage 2 complete: Received refined response from Gemini");
                Log.Information("Hybrid endpoint completed successfully");

                var finalResponse = geminiResponse.Candidates[0].Content.Parts[0].Text;

                return Results.Ok(new
                {
                    response = finalResponse,
                    pipeline = new
                    {
                        stage1 = "OpenAI GPT-4o-mini",
                        stage2 = "Google Gemini 2.5 Flash",
                        description = "Response processed through GPT then refined by Gemini"
                    }
                });
            }
            catch (ArgumentException ex)
            {
                Log.Error(ex, "Invalid argument provided to Hybrid endpoint");
                return Results.BadRequest(new { error = "Invalid request parameters", details = ex.Message });
            }
            catch (HttpRequestException ex)
            {
                Log.Error(ex, "Network error while calling AI APIs");
                return Results.Problem("Failed to connect to AI services", statusCode: 503);
            }
            catch (TaskCanceledException ex)
            {
                Log.Error(ex, "Request to AI APIs timed out");
                return Results.Problem("Request timed out", statusCode: 504);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Unexpected error in Hybrid endpoint: {ErrorMessage}", ex.Message);
                return Results.Problem("An unexpected error occurred while processing your request", statusCode: 500);
            }
        });
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