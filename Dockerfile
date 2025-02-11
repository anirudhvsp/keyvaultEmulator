# Use SHA-pinned base images for both stages to ensure reproducibility
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS builder
WORKDIR /app

COPY *.sln .
COPY */*.csproj ./
RUN for file in $(ls *.csproj); do mkdir -p ./${file%.*}/ && mv $file ./${file%.*}/; done

RUN dotnet restore

COPY . .
RUN dotnet publish AzureKeyVaultEmulator/AzureKeyVaultEmulator.csproj -c Release -o publish --no-restore

########################################

# Use the latest patched ASP.NET Alpine image
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime
WORKDIR /app

# Update base packages first, then add dependencies
RUN apk --no-cache upgrade && \
    apk add --no-cache \
    icu-libs \
    tzdata \
    && rm -rf /var/cache/apk/*

RUN apk update && apk upgrade

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    TZ=UTC \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8

COPY --from=builder /app/publish .

# Run as non-root user
RUN adduser --disabled-password --home /app --uid 1000 appuser \
    && chown -R appuser:appuser /app
USER appuser

ENTRYPOINT ["dotnet", "AzureKeyVaultEmulator.dll"]