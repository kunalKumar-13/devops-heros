# Python Hello World (Flask)

A minimal **Flask** application serving a Hello World page.

| File | Purpose |
|---|---|
| `app.py` | the Flask app, bound to `0.0.0.0:5000` |
| `requirements.txt` | pins `flask==3.0.3` |
| `Dockerfile` | `python:3.12-slim` → `pip install -r requirements.txt` → `python app.py` |

**Dockerfile notes:** binding to `0.0.0.0` rather than `127.0.0.1` is essential — a
container that listens only on loopback is unreachable from outside, no matter what
`-p` says. `--no-cache-dir` keeps the pip cache out of the image.

## Build and run

```bash
cd python-app
docker build -t hello-python .
docker run -d --name python-hello -p 5100:5000 hello-python
```

Then open **http://localhost:5100**

## Real build and run output

```console
kunal@kunal-devops:~/devops-homework/05-docker-hello-world/python-app$ cat Dockerfile
# Slim official Python base image
FROM python:3.12-slim

WORKDIR /app

# Install dependencies first for better layer caching
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py ./

EXPOSE 5000

CMD ["python", "app.py"]

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/python-app$ docker build -t hello-python .
DEPRECATED: The legacy builder is deprecated and will be removed in a future release.
            Install the buildx component to build images with BuildKit:
            https://docs.docker.com/go/buildx/

Sending build context to Docker daemon  7.168kB

Step 1/7 : FROM python:3.12-slim
3.12-slim: Pulling from library/python
3550292b2150: Pulling fs layer
ab2cb3ee67af: Pulling fs layer
8aff2d3a9af8: Pulling fs layer
bf7af0229701: Pulling fs layer
3550292b2150: Download complete
f392c22314d9: Download complete
d8d4cdf3552b: Download complete
ab2cb3ee67af: Download complete
bf7af0229701: Download complete
ab2cb3ee67af: Pull complete
bf7af0229701: Pull complete
8aff2d3a9af8: Download complete
8aff2d3a9af8: Pull complete
3550292b2150: Pull complete
Digest: sha256:78387bc3881b8273120a12ebe6c1ab22b018ccc2c9adf565ae1ac9b536e184ea
Status: Downloaded newer image for python:3.12-slim
 ---> 78387bc3881b
Step 2/7 : WORKDIR /app
 ---> Running in 79c29a213e7e
 ---> Removed intermediate container 79c29a213e7e
 ---> 1975e0ff18b0
Step 3/7 : COPY requirements.txt ./
 ---> 9ba7b1a33d85
Step 4/7 : RUN pip install --no-cache-dir -r requirements.txt
 ---> Running in dc994a2987f2
Collecting flask==3.0.3 (from -r requirements.txt (line 1))
  Downloading flask-3.0.3-py3-none-any.whl.metadata (3.2 kB)
Collecting Werkzeug>=3.0.0 (from flask==3.0.3->-r requirements.txt (line 1))
  Downloading werkzeug-3.1.8-py3-none-any.whl.metadata (4.0 kB)
Collecting Jinja2>=3.1.2 (from flask==3.0.3->-r requirements.txt (line 1))
  Downloading jinja2-3.1.6-py3-none-any.whl.metadata (2.9 kB)
Collecting itsdangerous>=2.1.2 (from flask==3.0.3->-r requirements.txt (line 1))
  Downloading itsdangerous-2.2.0-py3-none-any.whl.metadata (1.9 kB)
Collecting click>=8.1.3 (from flask==3.0.3->-r requirements.txt (line 1))
  Downloading click-8.5.0-py3-none-any.whl.metadata (2.6 kB)
Collecting blinker>=1.6.2 (from flask==3.0.3->-r requirements.txt (line 1))
  Downloading blinker-1.9.0-py3-none-any.whl.metadata (1.6 kB)
Collecting MarkupSafe>=2.0 (from Jinja2>=3.1.2->flask==3.0.3->-r requirements.txt (line 1))
  Downloading markupsafe-3.0.3-cp312-cp312-manylinux2014_aarch64.manylinux_2_17_aarch64.manylinux_2_28_aarch64.whl.metadata (2.7 kB)
Downloading flask-3.0.3-py3-none-any.whl (101 kB)
Downloading blinker-1.9.0-py3-none-any.whl (8.5 kB)
Downloading click-8.5.0-py3-none-any.whl (125 kB)
Downloading itsdangerous-2.2.0-py3-none-any.whl (16 kB)
Downloading jinja2-3.1.6-py3-none-any.whl (134 kB)
Downloading werkzeug-3.1.8-py3-none-any.whl (226 kB)
Downloading markupsafe-3.0.3-cp312-cp312-manylinux2014_aarch64.manylinux_2_17_aarch64.manylinux_2_28_aarch64.whl (24 kB)
Installing collected packages: MarkupSafe, itsdangerous, click, blinker, Werkzeug, Jinja2, flask
Successfully installed Jinja2-3.1.6 MarkupSafe-3.0.3 Werkzeug-3.1.8 blinker-1.9.0 click-8.5.0 flask-3.0.3 itsdangerous-2.2.0
[91mWARNING: Running pip as the 'root' user can result in broken permissions and conflicting behaviour with the system package manager, possibly rendering your system unusable. It is recommended to use a virtual environment instead: https://pip.pypa.io/warnings/venv. Use the --root-user-action option if you know what you are doing and want to suppress this warning.
[0m[91m
[notice] A new release of pip is available: 25.0.1 -> 26.2.1
[notice] To update, run: pip install --upgrade pip
[0m ---> Removed intermediate container dc994a2987f2
 ---> 89a85c5b435b
Step 5/7 : COPY app.py ./
 ---> dc100eb17779
Step 6/7 : EXPOSE 5000
 ---> Running in 5a0f326ec8df
 ---> Removed intermediate container 5a0f326ec8df
 ---> a24baf08c74f
Step 7/7 : CMD ["python", "app.py"]
 ---> Running in 5881faa0f6b1
 ---> Removed intermediate container 5881faa0f6b1
 ---> 3a364c35e12f
Successfully built 3a364c35e12f
Successfully tagged hello-python:latest

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/python-app$ docker run -d --name python-hello -p 5100:5000 hello-python
3120276c241530fe86fc721a575c90f884864c0f882f928009cb44cc9f8f19be

kunal@kunal-devops:~/devops-homework/05-docker-hello-world/python-app$ docker ps --filter name=python-hello --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
NAMES          IMAGE          STATUS         PORTS
python-hello   hello-python   Up 4 seconds   0.0.0.0:5100->5000/tcp, [::]:5100->5000/tcp
```

## Screenshot

![Python Hello World (Flask)](../screenshots/python-app.png)
