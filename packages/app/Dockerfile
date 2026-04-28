# syntax=docker/dockerfile:1.5
# ─────────────────────────────────────────────────────────────────────────────
# Stage 1 – Flutter web build
# ─────────────────────────────────────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS build

# Build-time env vars — baked into the Flutter web bundle via flutter_dotenv
ARG API_BASE_URL
ARG MAPBOX_ACCESS_TOKEN
ARG GOOGLE_PLACES_API_KEY

WORKDIR /app

# Copy dependency manifests first to exploit layer caching
COPY pubspec.yaml pubspec.lock ./

# Fetch pub packages (only re-runs when pubspec files change)
RUN flutter pub get

# Copy the rest of the source tree
COPY . .

# Write the .env asset that flutter_dotenv will embed at build time
RUN printf 'API_BASE_URL=%s\nMAPBOX_ACCESS_TOKEN=%s\nGOOGLE_PLACES_API_KEY=%s\n' \
    "$API_BASE_URL" \
    "$MAPBOX_ACCESS_TOKEN" \
    "$GOOGLE_PLACES_API_KEY" \
    > .env

# Build Flutter web (output lands in build/web/)
RUN flutter build web --release

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2 – nginx static file server
# ─────────────────────────────────────────────────────────────────────────────
FROM nginx:alpine AS final

RUN rm /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/conf.d/app.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
