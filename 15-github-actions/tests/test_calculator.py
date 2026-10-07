import pytest

from app.calculator import add, divide, multiply, percentage, subtract


def test_add():
    assert add(2, 3) == 5


def test_subtract():
    assert subtract(10, 4) == 6


def test_multiply():
    assert multiply(6, 7) == 42


def test_divide():
    assert divide(9, 3) == 3


def test_divide_by_zero_is_rejected():
    with pytest.raises(ValueError, match="divide by zero"):
        divide(1, 0)


def test_percentage():
    assert percentage(45, 60) == 75.0
