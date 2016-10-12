"""
A function that takes another function as an argument

"""


def decorator_function(original_function):
    def wrapper_function():
        print('wrapper_function executed this before {}'.format(original_function.__name__))
        return original_function()

    return wrapper_function


@decorator_function
def display():
    print("Display function ran!")


@decorator_function
def display_info(name, age):
    print('display_info ran with arguments {} and {}'.format(name, age))


# -- First approach
# decorated_display = decorator_function(display)
# decorated_display()

# Second approach with annotation
display_info('Prajesh', 29)
