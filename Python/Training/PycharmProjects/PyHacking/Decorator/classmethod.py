# Python OOP

"""
A class is a blueprint of creating our instances

Think of __init__ as the constructor of the class

self keyword is the instance of the class

"""


class Employee:
    raise_amount = 1.04
    num_of_emps = 0

    def __init__(self, first, last, pay):
        self.first = first;
        self.last = last;
        self.pay = pay;
        self.email = first + '.' + last + '@company.com'
        Employee.num_of_emps += 1

    def fullname(self):
        return '{} {}'.format(self.first, self.last)

    def apply_raise(self):
        self.pay = int(self.pay * self.raise_amount)

    @classmethod
    def set_raise_amt(cls, amount):
        cls.raise_amount * amount


emp_1 = Employee('Prajesh', 'Ananthan', 5000)
emp_2 = Employee('Ali', 'Ahmad', 3000)

# toString variant of an object
print(emp_1.__dict__)
