"""
Passing the reference of a function to another function as a parameter
"""


def sum(v1, v2):
    return v1 + v2


def main(calculate=sum):
    print(calculate(2, 2))


if __name__ == '__main__':
    main()
