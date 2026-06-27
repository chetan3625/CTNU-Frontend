# Stage 1: Build the Flutter Web application
FROM instrumentisto/flutter:stable AS build-env

# Set working directory
WORKDIR /app

# Copy the project files
COPY . .

# Enable web support and fetch dependencies
RUN flutter config --enable-web
RUN flutter pub get

# Build the release web package
RUN flutter build web --release

# Stage 2: Serve the compiled static files using Nginx
FROM nginx:alpine

# Copy the compiled web folder from the build stage to Nginx html directory
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Expose port 80 for Render routing
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
