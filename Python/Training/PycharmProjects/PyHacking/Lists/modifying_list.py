list = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

list.append(12)
print(list)

list2 = [13, 14, 15]
list.extend(list2)
print(list)

# Remove value from list
list.remove(5)
print(list)

# Reverses the list and adds value at the front
list.reverse()
list.append(0)
list.reverse()
print(list)
