# Small official Node base image
FROM node:20-alpine

# Everything happens inside /app in the container
WORKDIR /app

# Copy the manifest first so Docker can cache the npm install layer
COPY package.json ./
RUN npm install --omit=dev

# Now copy the application source
COPY server.js ./

# Document the port the app listens on
EXPOSE 3000

CMD ["node", "server.js"]
