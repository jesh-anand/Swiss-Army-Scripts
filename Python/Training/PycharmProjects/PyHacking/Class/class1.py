# Python OOP

"""
A class is a blueprint of creating our instances

Think of __init__ as the constructor of the class

self keyword is the instance of the class

"""


class Employee:
    raise_amount = 1.04

    def __init__(self, first, last, pay):
        self.first = first;
        self.last = last;
        self.pay = pay;
        self.email = first + '.' + last + '@company.com'

    def fullname(self):
        return '{} {}'.format(self.first, self.last)

    def apply_raise(self):
        self.pay = int(self.pay * self.raise_amount)


emp_1 = Employee('Prajesh', 'Ananthan', 5000)
emp_2 = Employee('Ali', 'Ahmad', 3000)

print(emp_1.email)
print(emp_1.raise_amount)
print(emp_1.pay)
emp_1.apply_raise()
print(emp_1.pay)

print(emp_1.__dict__)
