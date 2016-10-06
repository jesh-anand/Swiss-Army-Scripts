class Person:
    def __init__(self, gender, name):
        self.gender = gender
        self.name = name

    def display(self):
        print('I am a ', self.gender, ' , and my name is ', self.name)

# TODO: What is self for?
People = Person('male', 'Prajesh')
People.display()
