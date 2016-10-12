class Employee:
    def __init__(self, first, last):
        self.first = first
        self.last = last

    @property
    def email(self):
        return '{}.{}@company.com'.format(self.first, self.last)

    @property
    def fullname(self):
        return '{} {}'.format(self.first, self.last)

    @fullname.setter
    def fullname(self, name):
        first, last = name.split(' ')
        self.first = first
        self.last = last

    @fullname.deleter
    def fullname(self):
        print('Name deleted!')
        self.first = None
        self.last = None

emp1 = Employee('Prajesh', 'Ananthan')

# Access like a method withot the property annotation
# Try removing the poroperty annotation
emp1.fullname = 'Prajesh Ananthan'

# Access like an instance variable with @property annotation
print(emp1.email)

# Using the deleter
del emp1.fullname



