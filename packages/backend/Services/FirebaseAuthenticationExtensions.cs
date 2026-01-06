namespace backend.Services;
public static class FirebaseAuthenticationExtensions
{
    public static AuthenticationBuilder AddFirebaseAuthentication(this IServiceCollection services)
    {
        return services.AddAuthentication("Firebase")
            .AddScheme<AuthenticationSchemeOptions, FirebaseAuthenticationHandler>("Firebase", _ => { });
    }
}
