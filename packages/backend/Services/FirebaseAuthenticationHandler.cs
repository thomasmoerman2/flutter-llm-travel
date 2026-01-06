namespace backend.Services;
public class FirebaseAuthenticationHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public FirebaseAuthenticationHandler(IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger, UrlEncoder encoder, ISystemClock clock)
        : base(options, logger, encoder, clock)
    {
    }
    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        try
        {
            // Check if Authorization header exists
            if (!Request.Headers.ContainsKey("Authorization"))
            {
                return AuthenticateResult.NoResult();
            }
            var authHeader = Request.Headers["Authorization"].ToString();
            if (!authHeader.StartsWith("Bearer "))
            {
                return AuthenticateResult.NoResult();
            }
            var token = authHeader.Substring(7); // Remove "Bearer " prefix
            // Verify token with Firebase
            var decodedToken = await FirebaseAuth.DefaultInstance.VerifyIdTokenAsync(token);
            // Create claims from Firebase token
            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, decodedToken.Uid),
                new Claim(ClaimTypes.Name, decodedToken.Uid),
                new Claim("uid", decodedToken.Uid)
            };
            // Add additional claims from Firebase token
            foreach (var claim in decodedToken.Claims)
            {
                if (claim.Key == "email")
                {
                    claims.Add(new Claim(ClaimTypes.Email, claim.Value.ToString()));
                }
                claims.Add(new Claim(claim.Key, claim.Value.ToString()));
            }
            var identity = new ClaimsIdentity(claims, Scheme.Name);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, Scheme.Name);
            Logger.LogInformation($"Firebase authentication successful for UID: {decodedToken.Uid}");
            return AuthenticateResult.Success(ticket);
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "Firebase authentication failed");
            return AuthenticateResult.Fail(ex.Message);
        }
    }
}
