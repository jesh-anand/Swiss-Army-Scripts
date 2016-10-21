from tkinter import *

"""A script that displays 4 button on a window

The intention is to showcase how to place buttons in a window with
implementation below:

    eg. button1.pack(side=LEFT)

"""
root = Tk()

# Make a container and put it inside a window (the root)
topframe = Frame(root)

# Pack it to make it invisible
topframe.pack()

bottomframe = Frame(root)
bottomframe.pack(side=BOTTOM)

# Include button into the window
button1 = Button(topframe, text='Button1', fg='red')
button2 = Button(topframe, text='Button2', fg='blue')
button3 = Button(topframe, text='Button3', fg='green')
button4 = Button(bottomframe, text='Button4', fg='purple')

# Pack the button and place them at the side of each other
button1.pack(side=LEFT)
button2.pack(side=LEFT)
button3.pack(side=LEFT)
button4.pack()

root.mainloop()
