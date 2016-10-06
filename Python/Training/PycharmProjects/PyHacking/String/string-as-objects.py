string = ['P', 'R', 'A', 'J', 'E', 'S', 'H']

name = 'prajesh ananthan'

# -- Print the characters in the String
for letter in name:
    print(letter)

# -- Return the index of char in String
print(string.count('R'))

# -- Capitalizes the starting word for each phrase
print(name.title())

with open('file_to_write', 'w') as f:
    f.write('file contents')
