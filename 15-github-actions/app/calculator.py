"""A small calculator: the code the Session 16 pipeline tests, builds and ships."""


def add(a: float, b: float) -> float:
    return a + b


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


if __name__ == "__main__":
    print("add(10, 5)        =", add(10, 5))
    print("subtract(10, 5)   =", subtract(10, 5))
    print("multiply(10, 5)   =", multiply(10, 5))
    print("divide(10, 5)     =", divide(10, 5))
    print("percentage(45, 60) =", percentage(45, 60))
