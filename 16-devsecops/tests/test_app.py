import pytest

from app.main import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    return app.test_client()


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.get_json()["status"] == "ok"


def test_greet_default(client):
    assert client.get("/greet").get_json()["message"] == "Hello, world!"


def test_greet_name_is_trimmed_and_capped(client):
    long_name = "x" * 200
    msg = client.get(f"/greet?name={long_name}").get_json()["message"]
    assert len(msg) == len("Hello, !") + 50


def test_add(client):
    assert client.get("/add?a=2&b=3.5").get_json()["result"] == 5.5


def test_add_rejects_bad_input(client):
    assert client.get("/add?a=two&b=3").status_code == 400
