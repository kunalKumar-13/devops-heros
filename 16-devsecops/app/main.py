"""A small Flask API: the thing the Session 17 DevSecOps pipeline secures.

Deliberately simple, so every finding the scanners report is about the
supply chain (dependencies, base image, secrets) rather than app logic.
"""
import os

from flask import Flask, jsonify, request

app = Flask(__name__)


@app.get("/health")
def health():
    return jsonify(status="ok", version=os.getenv("APP_VERSION", "local"))


@app.get("/greet")
def greet():
    name = request.args.get("name", "world").strip()[:50] or "world"
    return jsonify(message=f"Hello, {name}!")


@app.get("/add")
def add():
    try:
        a = float(request.args["a"])
        b = float(request.args["b"])
    except (KeyError, ValueError):
        return jsonify(error="a and b must be numbers"), 400
    return jsonify(result=a + b)


if __name__ == "__main__":
    # bind to all interfaces only inside the container; nosec documents the decision for bandit
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8080")))  # nosec B104
