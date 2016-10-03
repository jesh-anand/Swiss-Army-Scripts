def function_name():
    return "A return value"


print(function_name())


# -- returns a 'none' which is same with null in Java
def function_name2():
    return


var = function_name2()

if var == None:
    print('true')


# We can return more than 1 value in Python
def getFullname():
    return 'Prajesh', 'Ananthan'

a, b = getFullname()
print(a + " : " + b)
