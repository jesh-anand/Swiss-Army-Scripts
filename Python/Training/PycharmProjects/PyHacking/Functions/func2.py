# Use of global variable
list1 = [1, 2, 3, 4]


def test_function(lists):
    "This is simply to demonstrate passing a value by reference"
    lists.append([5, 6, 7, 8])
    return


print("The initial value: ", list1)

test_function(list1)
print("The after value: ", list1)
