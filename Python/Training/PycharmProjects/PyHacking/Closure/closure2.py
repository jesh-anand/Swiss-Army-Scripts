"""
Closures can avoid the use of global values and provides some form of data hiding.
It can also provide an object oriented solution to the problem.

When there are few methods (one method in most cases) to be implemented in a class,
closures can provide an alternate and more elegant solutions.

But when the number of attributes and methods get larger, better implement a class.

Reference: http://www.programiz.com/python-programming/closure

"""


def make_multiplier_of(n):
    def multiplier(x):
        print(n)
        print(x)
        return x * n

    return multiplier


# Multiplier of 3
times3 = make_multiplier_of(3)

# Multiplier of 5
times5 = make_multiplier_of(5)

# Output: 27
print(times3(9))

# Output: 15
print(times5(3))

# Output: 30
print(times5(times3(2)))
