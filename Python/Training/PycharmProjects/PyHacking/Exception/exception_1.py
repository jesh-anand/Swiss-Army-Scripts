try:
    f = open('corrupt_file.txt')
    if f.name == 'corrupt_file.txt':
        raise Exception
except FileNotFoundError:
    print('Sorry. File not found!')
except Exception as e:
    print('Sorry. This file is corrupted!')
else:
    print(f.read())
    f.close()
finally:
    print('We have reached the final block!')