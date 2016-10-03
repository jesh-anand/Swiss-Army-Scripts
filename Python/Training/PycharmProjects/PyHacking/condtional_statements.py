a = 0
b = 1

if a == b:
    print(True)
else:
    print(False)

if a <= b:
    print('This is true!')

# Using keyword 'and' with elif statement
if a > b and b > 0:
    print('This is expected!')
elif b > a:
    print('b is more than a')
