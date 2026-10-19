var builder = WebApplication.CreateBuilder(args);

var app = builder.Build();

// Minimal endpoints returning static data. Kong proxies to these.
app.MapGet("/", () => "C# Web API is up. Try /hello or /products.");

app.MapGet("/hello", () => new
{
    message = "Hello from the C# Web API, proxied through Kong!",
    timestamp = DateTimeOffset.UtcNow
});

app.MapGet("/products", () => new[]
{
    new { id = 1, name = "Keyboard", price = 49.99 },
    new { id = 2, name = "Mouse", price = 19.99 },
    new { id = 3, name = "Monitor", price = 199.99 }
});

app.Run();
