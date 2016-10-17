nums = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

# my_list = []
# for n in nums:
#     my_list.append(n)
# print(my_list)


# I want n for each n in nums
# my_list = [n for n in nums]
# print(my_list)


# I want n*n for each n in nums
# my_list = []
# for n in nums:
#     my_list.append(n*n)
# print(my_list)

# my_list = [n*n for n in nums]
# print(my_list)


# I want n for each n in nums if n is even
# my_list = []
# for n in nums:
#     if (n % 2) == 0:
#         my_list.append(n)
# print(my_list)

# my_list = [n for n in nums if n % 2 == 0]
# print(my_list)

# I want letter num pair
# my_list = []
# for letter in 'abcd':
#     for num in range(4):
#         my_list.append((letter, num))
# print(my_list)

# my_list = [(letter, num) for letter in 'abcd' for num in range(4)]
# print(my_list)

names = ['Bruce', 'Clark', 'Peter', 'Logan', 'Wade']
heroes = ['Batman', 'Superman', 'Spiderman', 'Wolverine', 'Deadpool']

# -- Key value insertion into the hash using the built in zip function
my_dict = {}
for name, hero in zip(names, heroes):
    my_dict[name] = hero
print(my_dict)

# Same approach but with comprehension
# my_dict = {name: hero for name, hero in zip(names, heroes)}
# print(my_dict)

# Insert key value pair with some filtering
my_dict = {name: hero for name, hero in zip(names, heroes) if name != 'Bruce'}
print(my_dict)
