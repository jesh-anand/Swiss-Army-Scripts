file = open('files/text.txt')

# -- end keyword used to replace newline characters
for line in file:
    print(line, end='')
