class Animals:
    def eat(self):
        print('I can eat!')

    def talk(self):
        print('I can talk!')


# -- Inheritance is applied here with Anumals as super class
class Cat(Animals):
    def talk(self):
        print('meow')

    def move(self):
        print('I can move')


animal = Cat()
animal.eat()
