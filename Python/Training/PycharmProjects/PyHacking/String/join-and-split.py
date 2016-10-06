"""String split function

"""
string = "a-b-c-d-e-f"

sequence = string.split('-')

for letter in sequence:
    print(letter)

"""String join function

"""

sep = '/'
letters = sep.join(sequence)
print(letters)
