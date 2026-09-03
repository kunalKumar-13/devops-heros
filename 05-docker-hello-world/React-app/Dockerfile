# ---- build stage: install dependencies and produce the static bundle ----
FROM node:20-alpine AS build
WORKDIR /app

# Manifest first, so the dependency layer is cached between builds
COPY package.json ./
RUN npm install

# Then the source, and build the production bundle into /app/dist
COPY . .
RUN npm run build

# ---- run stage: serve the static bundle with Nginx ----
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80
