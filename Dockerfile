# Dockerfile
# Stage 1: Build the application
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

WORKDIR /src

# Copy project files
COPY . ./

# Restore and build the specific PKHeX solution file
RUN dotnet restore PKHeX.sln
RUN dotnet build PKHeX.sln -c Release --no-restore
RUN dotnet publish PKHeX.WinForms/PKHeX.WinForms.csproj -c Release -o /app/out --no-build --no-restore

# Stage 2: Create runtime image
FROM alpine:latest AS runtime

WORKDIR /app

# Copy the built application from the build stage
COPY --from=build /app/out ./

# Create a script to copy files to volume
RUN echo 'cp -r /app/* /pkhex-output/' > /copy.sh && chmod +x /copy.sh

VOLUME /pkhex-output
CMD ["/bin/sh", "/copy.sh"]
