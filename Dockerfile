# ----------------------------------------------------------------------------------
# Multi-stage build for a smaller final image.
# Stage 1: Build Stage (Optional for static files, but good practice for future assets)
# ----------------------------------------------------------------------------------
FROM node:20-slim AS builder

# Set the working directory
WORKDIR /app

# Copy all HTML files and the style.css file using wildcards for better maintainability.
# This aligns with your project structure: all pages are in the root.
COPY *.html style.css ./
# Copy the entire assets directory
COPY assets ./assets

# ----------------------------------------------------------------------------------
# Stage 2: Final Nginx Production Image
# ----------------------------------------------------------------------------------
FROM nginx:alpine

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy static assets from the builder stage into the Nginx public folder
COPY --from=builder /app /usr/share/nginx/html

# Expose port 80 (standard HTTP port)
EXPOSE 80

# Default command starts Nginx (defined by the base image)
# CMD ["nginx", "-g", "daemon off;"]
