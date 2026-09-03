# React Hello World (Vite + Nginx)

A real **React** application built with **Vite** and served as a static bundle by Nginx.

| File | Purpose |
|---|---|
| `src/App.jsx` | the React component that renders *Hello World from React* |
| `src/main.jsx` | mounts the app into `#root` |
| `index.html`, `vite.config.js` | the Vite entry point and config |
| `package.json` | React 18 + Vite |
| `Dockerfile` | **multi-stage**: build with Node, serve with Nginx |

**Dockerfile notes:** this is the standard production pattern for a front-end app. Stage
one runs `npm install && npm run build` on `node:20-alpine` and produces `/app/dist`;
stage two copies only `dist` into `nginx:alpine`. Node and `node_modules` never reach
the final image — which is why it ends up at **102 MB** instead of several hundred.

**Note on verification:** `curl` returns the empty HTML shell because the heading is
rendered by JavaScript in the browser. The screenshot below is the real proof that the
page displays Hello World.

## Build and run

```bash
cd React-app
docker build -t hello-react .
docker run -d --name react-hello -p 3101:80 hello-react
```

Then open **http://localhost:3101**

## Real build and run output

```console
kunal@kunal-devops:~/devops-homework/05-docker-hello-world/React-app$ cat Dockerfile
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

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/React-app$ docker build -t hello-react .
DEPRECATED: The legacy builder is deprecated and will be removed in a future release.
            Install the buildx component to build images with BuildKit:
            https://docs.docker.com/go/buildx/

Sending build context to Docker daemon  13.31kB

Step 1/9 : FROM node:20-alpine AS build
 ---> fb4cd12c85ee
Step 2/9 : WORKDIR /app
 ---> Using cache
 ---> a80e00f10731
Step 3/9 : COPY package.json ./
 ---> f00cc2b27780
Step 4/9 : RUN npm install
 ---> Running in 628b8561ce61

added 62 packages, and audited 63 packages in 8s

7 packages are looking for funding
  run `npm fund` for details
[91mnpm notice
npm notice New major version of npm available! 10.8.2 -> 12.0.2
npm notice Changelog: https://github.com/npm/cli/releases/tag/v12.0.2
npm notice To update run: npm install -g npm@12.0.2
npm notice
[0m
2 vulnerabilities (1 moderate, 1 high)

To address all issues (including breaking changes), run:
  npm audit fix --force

Run `npm audit` for details.
 ---> Removed intermediate container 628b8561ce61
 ---> 045eedc72cda
Step 5/9 : COPY . .
 ---> 8ac23ba1574e
Step 6/9 : RUN npm run build
 ---> Running in 442580b78f6d

> react-hello-world@1.0.0 build
> vite build

vite v5.4.21 building for production...
transforming...
✓ 31 modules transformed.
rendering chunks...
computing gzip size...
dist/index.html                   0.40 kB │ gzip:  0.27 kB
dist/assets/index-CBZ5nGWe.css    0.10 kB │ gzip:  0.11 kB
dist/assets/index-Dfqor15E.js   142.78 kB │ gzip: 45.86 kB
✓ built in 356ms
 ---> Removed intermediate container 442580b78f6d
 ---> 4ac0dab04447
Step 7/9 : FROM nginx:alpine
alpine: Pulling from library/nginx
5de55e5ef9c0: Pulling fs layer
badda8760139: Pulling fs layer
accee44535cd: Pulling fs layer
9592924c961c: Pulling fs layer
1791812138bb: Pulling fs layer
2123acec2175: Pulling fs layer
d6c1262595ab: Pulling fs layer
853498d24c3c: Pulling fs layer
9592924c961c: Download complete
853498d24c3c: Download complete
d6c1262595ab: Download complete
5de55e5ef9c0: Download complete
2123acec2175: Download complete
1791812138bb: Download complete
5de55e5ef9c0: Pull complete
a855f9d558c0: Download complete
accee44535cd: Download complete
9592924c961c: Pull complete
853498d24c3c: Pull complete
d6c1262595ab: Pull complete
2123acec2175: Pull complete
1791812138bb: Pull complete
accee44535cd: Pull complete
c4f99b055a72: Download complete
badda8760139: Download complete
badda8760139: Pull complete
Digest: sha256:a9ae6f6d078d477e21323310498e5196cb2b7c0aedd9e07b7306612077227d7c
Status: Downloaded newer image for nginx:alpine
 ---> a9ae6f6d078d
Step 8/9 : COPY --from=build /app/dist /usr/share/nginx/html
 ---> 46b7a66460b8
Step 9/9 : EXPOSE 80
 ---> Running in 60837b58543d
 ---> Removed intermediate container 60837b58543d
 ---> 42494398b2bb
Successfully built 42494398b2bb
Successfully tagged hello-react:latest

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/React-app$ docker run -d --name react-hello -p 3101:80 hello-react
78b99130ed0f1709492eab7a5d80db5f666fe68ff7a3243863248eabc35489b2

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/React-app$ docker ps --filter name=react-hello --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
NAMES         IMAGE         STATUS         PORTS
react-hello   hello-react   Up 4 seconds   0.0.0.0:3101->80/tcp, [::]:3101->80/tcp
```

## Screenshot

![React Hello World (Vite + Nginx)](../screenshots/React-app.png)
