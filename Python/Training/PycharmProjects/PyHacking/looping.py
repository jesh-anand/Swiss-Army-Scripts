a = 0
# while a < 100:
    # print(a)
    # a += 1
# print('This is done!')


# Using for loop
# for data in [1,2,3,4,5]:
#     print(data)

var = 'prajesh'
for val in var:
    print(val)

# TODO: Study enumurate
for key, data in enumerate('prajesh'):
    if key % 2 == 0:
        print('The letter {} is on an even location of {}'.format(data, key))
    if key % 4 == 0:
        print('The letter is {}'.format(data))
