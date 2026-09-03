# Apache Hello World (httpd)

A static Hello World page served by the **Apache HTTP Server**.

| File | Purpose |
|---|---|
| `index.html` | the page |
| `Dockerfile` | `httpd:2.4` with `index.html` copied into `/usr/local/apache2/htdocs/` |

**Dockerfile notes:** the official `httpd` image already starts Apache in the
foreground, so no `CMD` is needed — the whole Dockerfile is a `FROM` and a `COPY`.
Apache's document root inside this image is `/usr/local/apache2/htdocs`.

## Build and run

```bash
cd Apache-app
docker build -t hello-apache .
docker run -d --name apache-hello -p 8181:80 hello-apache
```

Then open **http://localhost:8181**

## Real build and run output

```console
kunal@kunal-devops:~/devops-homework/05-docker-hello-world/Apache-app$ cat Dockerfile
# Official Apache HTTP Server image
FROM httpd:2.4

# httpd serves everything under this directory
COPY index.html /usr/local/apache2/htdocs/index.html

EXPOSE 80
# The base image already starts httpd in the foreground, so no CMD is needed.

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/Apache-app$ docker build -t hello-apache .
DEPRECATED: The legacy builder is deprecated and will be removed in a future release.
            Install the buildx component to build images with BuildKit:
            https://docs.docker.com/go/buildx/

Sending build context to Docker daemon  5.632kB

Step 1/3 : FROM httpd:2.4
2.4: Pulling from library/httpd
fff91e36faf1: Pulling fs layer
4f4fb700ef54: Pulling fs layer
01289bdb7344: Pulling fs layer
cea950926c89: Pulling fs layer
91eac6ee2743: Pulling fs layer
fff91e36faf1: Download complete
01289bdb7344: Download complete
4f4fb700ef54: Download complete
cea950926c89: Download complete
01289bdb7344: Pull complete
4f4fb700ef54: Pull complete
cea950926c89: Pull complete
d461d957ad8a: Download complete
91eac6ee2743: Download complete
fff91e36faf1: Pull complete
91eac6ee2743: Pull complete
e78b009430d6: Download complete
Digest: sha256:979c38c2228d28c2edfd45c6e27dcee1c7b4a101a5526721ae8ece454e89e99e
Status: Downloaded newer image for httpd:2.4
 ---> 979c38c2228d
Step 2/3 : COPY index.html /usr/local/apache2/htdocs/index.html
 ---> a881023f7982
Step 3/3 : EXPOSE 80
 ---> Running in e68af0580021
 ---> Removed intermediate container e68af0580021
 ---> e738b0fd797c
Successfully built e738b0fd797c
Successfully tagged hello-apache:latest

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/Apache-app$ docker run -d --name apache-hello -p 8181:80 hello-apache
d9e798810f71cf08e3be5b4a870760fef0c8575a09060685191820028a317e6d

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/Apache-app$ docker ps --filter name=apache-hello --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
NAMES          IMAGE          STATUS         PORTS
apache-hello   hello-apache   Up 4 seconds   0.0.0.0:8181->80/tcp, [::]:8181->80/tcp
```

## Screenshot

![Apache Hello World (httpd)](../screenshots/Apache-app.png)
