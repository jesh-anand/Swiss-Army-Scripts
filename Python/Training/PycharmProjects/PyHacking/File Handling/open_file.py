file = open('files/text.txt')

# -- end keyword used to replace newline characters
for line in file:
    print(line, end='')

""" Alternative way of reading a file. """

with open("files/test.txt", "a") as myfile:
    myfile.write("Hello World")

