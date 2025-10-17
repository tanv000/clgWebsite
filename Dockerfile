# ----------------------------------------------------------------------------------
# Stage 1: Build Stage (Builder) - Used to copy all local assets cleanly
# ----------------------------------------------------------------------------------
FROM node:20-slim AS builder

# Set the working directory
WORKDIR /app

# Copy all HTML files, the style.css (if present), and the assets directory
COPY *.html .
COPY style.css .
COPY assets ./assets

# ----------------------------------------------------------------------------------
# Stage 2: Final Nginx Production Image (Minimal and secure)
# ----------------------------------------------------------------------------------
FROM nginx:alpine

# Remove the default Nginx configuration file
RUN rm /etc/nginx/conf.d/default.conf

# Copy the custom Nginx configuration file (nginx.conf)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy static website files from the 'builder' stage into the Nginx public folder
COPY --from=builder /app /usr/share/nginx/html

# Expose port 80 (standard HTTP port)
EXPOSE 80

# The default command starts Nginx (defined by the base image)
# CMD ["nginx", "-g", "daemon off;"] 
