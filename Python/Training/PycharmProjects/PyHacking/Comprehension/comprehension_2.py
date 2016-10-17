nums = [1, 1, 2, 3, 3, 4, 6, 7, 8, 8, 9, 10, 10]

# -- Using sets that removes duplicates
my_set = set()
for n in nums:
    if (n != 10):
        my_set.add(n)
print(my_set)

my_set2 = set(n for n in nums if n != 10)
print(my_set2)
