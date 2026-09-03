# Node.js Hello World (Express)

A minimal **Express** server that responds with a Hello World page.

| File | Purpose |
|---|---|
| `server.js` | the Express app, listening on port 3000 |
| `package.json` | declares the `express` dependency and the `start` script |
| `Dockerfile` | `node:20-alpine` → `npm install` → `node server.js` |
| `.dockerignore` | keeps `node_modules` out of the build context |

**Dockerfile notes:** `package.json` is copied *before* the source so the
`npm install` layer is cached and only re-runs when dependencies change.
`--omit=dev` skips devDependencies in the image.

## Build and run

```bash
cd nodejs-app
docker build -t hello-nodejs .
docker run -d --name node-hello -p 3100:3000 hello-nodejs
```

Then open **http://localhost:3100**

## Real build and run output

```console
kunal@kunal-devops:~/devops-homework/05-docker-hello-world/nodejs-app$ cat Dockerfile
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

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/nodejs-app$ docker build -t hello-nodejs .
DEPRECATED: The legacy builder is deprecated and will be removed in a future release.
            Install the buildx component to build images with BuildKit:
            https://docs.docker.com/go/buildx/

Sending build context to Docker daemon  8.704kB

Step 1/7 : FROM node:20-alpine
20-alpine: Pulling from library/node
cd322d0ddd02: Pulling fs layer
13e45b12880f: Pulling fs layer
bda5d7ef971f: Pulling fs layer
d17f077ada11: Pulling fs layer
cd322d0ddd02: Download complete
d17f077ada11: Download complete
d17f077ada11: Pull complete
13e45b12880f: Download complete
e68c4317c820: Download complete
85e939e07fce: Download complete
bda5d7ef971f: Download complete
cd322d0ddd02: Pull complete
13e45b12880f: Pull complete
bda5d7ef971f: Pull complete
Digest: sha256:fb4cd12c85ee03686f6af5362a0b0d56d50c58a04632e6c0fb8363f609372293
Status: Downloaded newer image for node:20-alpine
 ---> fb4cd12c85ee
Step 2/7 : WORKDIR /app
 ---> Running in b0717919a9c7
 ---> Removed intermediate container b0717919a9c7
 ---> a80e00f10731
Step 3/7 : COPY package.json ./
 ---> f7502ae61f43
Step 4/7 : RUN npm install --omit=dev
 ---> Running in 56bc856aae14

added 68 packages, and audited 69 packages in 2s

15 packages are looking for funding
  run `npm fund` for details

3 moderate severity vulnerabilities

To address all issues, run:
  npm audit fix

Run `npm audit` for details.
[91mnpm notice
npm notice New major version of npm available! 10.8.2 -> 12.0.2
npm notice Changelog: https://github.com/npm/cli/releases/tag/v12.0.2
npm notice To update run: npm install -g npm@12.0.2
npm notice
[0m ---> Removed intermediate container 56bc856aae14
 ---> 288cc768cdc0
Step 5/7 : COPY server.js ./
 ---> 304fa2dddc85
Step 6/7 : EXPOSE 3000
 ---> Running in ede2136e0568
 ---> Removed intermediate container ede2136e0568
 ---> 4d7de9177d3d
Step 7/7 : CMD ["node", "server.js"]
 ---> Running in 313019fc77a0
 ---> Removed intermediate container 313019fc77a0
 ---> 149be07f3208
Successfully built 149be07f3208
Successfully tagged hello-nodejs:latest

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/nodejs-app$ docker run -d --name node-hello -p 3100:3000 hello-nodejs
2400edfec3bc56698d5aa64b2975d336c70abc5151665d5f978d534d0c201a69

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/nodejs-app$ docker ps --filter name=node-hello --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
NAMES        IMAGE          STATUS         PORTS
node-hello   hello-nodejs   Up 4 seconds   0.0.0.0:3100->3000/tcp, [::]:3100->3000/tcp
```

## Screenshot

![Node.js Hello World (Express)](../screenshots/nodejs-app.png)
