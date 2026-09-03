# Nginx Hello World

A static Hello World page served by **Nginx**.

| File | Purpose |
|---|---|
| `index.html` | the page |
| `Dockerfile` | `nginx:alpine` with `index.html` copied into `/usr/share/nginx/html/` |

**Dockerfile notes:** the Alpine variant keeps the image at ~102 MB. Nginx's document
root in this image is `/usr/share/nginx/html`, and the base image already runs nginx in
the foreground, so again no `CMD` is required.

## Build and run

```bash
cd nginx-app
docker build -t hello-nginx .
docker run -d --name nginx-hello -p 8182:80 hello-nginx
```

Then open **http://localhost:8182**

## Real build and run output

```console
kunal@kunal-devops:~/devops-homework/05-docker-hello-world/nginx-app$ cat Dockerfile
# Official Nginx image
FROM nginx:alpine

# nginx serves everything under this directory
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
# The base image already starts nginx in the foreground, so no CMD is needed.

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/nginx-app$ docker build -t hello-nginx .
DEPRECATED: The legacy builder is deprecated and will be removed in a future release.
            Install the buildx component to build images with BuildKit:
            https://docs.docker.com/go/buildx/

Sending build context to Docker daemon  5.632kB

Step 1/3 : FROM nginx:alpine
 ---> a9ae6f6d078d
Step 2/3 : COPY index.html /usr/share/nginx/html/index.html
 ---> a0a087544042
Step 3/3 : EXPOSE 80
 ---> Running in 9bd83f75e8de
 ---> Removed intermediate container 9bd83f75e8de
 ---> d7ca75e793b4
Successfully built d7ca75e793b4
Successfully tagged hello-nginx:latest

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/nginx-app$ docker run -d --name nginx-hello -p 8182:80 hello-nginx
0517ca08f2c574af8e366f93a6d5ed0e4b4f2b7726a368378308fdbcb6b88f95

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/nginx-app$ docker ps --filter name=nginx-hello --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
NAMES         IMAGE         STATUS         PORTS
nginx-hello   hello-nginx   Up 4 seconds   0.0.0.0:8182->80/tcp, [::]:8182->80/tcp
```

## Screenshot

![Nginx Hello World](../screenshots/nginx-app.png)
