from tkinter import *

"""A button that prints out text at the console when clicked"""


def main():
    root = Tk()
    button_1 = Button(root, text='Print', command=printName)
    button_1.pack()
    root.mainloop()


def printName():
    print('This is a button!')


if __name__ == '__main__':
    main()
