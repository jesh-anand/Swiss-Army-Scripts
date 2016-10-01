number = 3
# print(number)

a = 50.0
# print(type(a), a)

# Substitutes the value inside the string
b = 'Hello'
a = 'This is a {} String'.format(b)
# print(a)

# With brackets, it is called a tuple. A tuple is immutable
x = (1, 2, 3, 4, 5)
print(type(x), x)

# With square brackets, it is called a list
y = [1, 2, 3, 4, 5]
print(type(y), y)
# We can append to a list
y.append(6)
print(type(y), y)
# Prints out the range in the list
print(y[2:5])