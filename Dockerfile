# Stage 1: Build the Flutter Web application
FROM debian:bookworm-slim AS build-env

# Install dependencies required by the Flutter SDK
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Bypass tar ownership extraction errors in restricted container runtimes
RUN TAR_PATH=$(which tar) && \
    mv "$TAR_PATH" "${TAR_PATH}.original" && \
    echo '#!/bin/sh' > "$TAR_PATH" && \
    echo 'exec '"${TAR_PATH}"'.original --no-same-owner "$@"' >> "$TAR_PATH" && \
    chmod +x "$TAR_PATH"

# Clone the official stable Flutter SDK
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter

# Add Flutter to system path
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Pre-download Flutter binaries
RUN flutter doctor

# Set working directory
WORKDIR /app

# Copy the project files
COPY . .

# Enable web support and install dependencies
RUN flutter config --enable-web
RUN flutter pub get

# Build the release web package
RUN flutter build web --release

# Stage 2: Serve the compiled static files using Nginx
FROM nginx:alpine

# Copy the compiled web folder from build stage to Nginx html directory
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Expose port 80 for Render routing
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
