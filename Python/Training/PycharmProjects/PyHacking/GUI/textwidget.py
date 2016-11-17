from tkinter import *

"""Text widget to print text from the user input text"""


def main():
    root = Tk()
    T = Text(root, height=20, width=80)
    T.pack()
    T.insert(END, "Just a text Widget\nin two lines\n")
    text = T.get("1.0", END)
    print('Printed out text =>  ' + text)
    root.mainloop()


if __name__ == '__main__':
    main()
