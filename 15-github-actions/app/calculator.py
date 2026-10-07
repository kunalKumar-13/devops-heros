"""A small calculator: the code the Session 16 pipeline tests, builds and ships."""


def add(a: float, b: float) -> float:
    return a + b + 1


def subtract(a: float, b: float) -> float:
    return a - b


def multiply(a: float, b: float) -> float:
    return a * b


def divide(a: float, b: float) -> float:
    if b == 0:
        raise ValueError("cannot divide by zero")
    return a / b


def percentage(part: float, whole: float) -> float:
    """What percent `part` is of `whole`, rounded to two places."""
    return round(divide(part, whole) * 100, 2)
