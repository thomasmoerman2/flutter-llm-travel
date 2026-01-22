# syntax=docker/dockerfile:1.5
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
ARG configuration=Release
WORKDIR /src
COPY ["backend.csproj", "./"]
RUN --mount=type=cache,id=nuget,target=/root/.nuget/packages \
    dotnet restore "backend.csproj"
COPY . .
RUN --mount=type=cache,id=nuget,target=/root/.nuget/packages \
    dotnet publish "backend.csproj" -c $configuration -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
EXPOSE 5005
ENV ASPNETCORE_URLS=http://+:5005
RUN useradd --uid 10001 --create-home --shell /bin/bash appuser
COPY --from=build --chown=appuser:appuser /app/publish .
USER appuser
ENTRYPOINT ["dotnet", "backend.dll"]
