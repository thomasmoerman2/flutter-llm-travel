namespace backend.Exceptions;
public class CustomValidationException : Exception
{
    public IEnumerable<FluentValidation.Results.ValidationFailure> Errors { get; set; }
    public CustomValidationException(IEnumerable<FluentValidation.Results.ValidationFailure> errors) : base("Validation failed")
    {
        Errors = errors;
    }
}
