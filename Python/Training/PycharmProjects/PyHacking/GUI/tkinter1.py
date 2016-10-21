from tkinter import *

"""A window displaying a text label"""

root = Tk()

theLable = Label(root, text='This is too easy')

# Put the label in the window
theLable.pack()

# To make sure the window remains on screen
root.mainloop()
