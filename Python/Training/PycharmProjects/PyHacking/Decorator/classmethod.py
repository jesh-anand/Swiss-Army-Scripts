# Python OOP

"""
A class is a blueprint of creating our instances

Think of __init__ as the constructor of the class

self keyword is the instance of the class

cls keyword is the class itself with the @classmethod annotation

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
        cls.raise_amount = amount

    @classmethod
    def from_string(cls, emp_str):
        first, last, pay = emp_str.split('-')
        return cls(first, last, pay)


########## Main Function ############################

emp_string_1 = 'prajesh-ananthan-7000'
emp_string_2 = 'brandon-goh-6000'
emp_string_3 = 'wayne-lau-7000'

emp_str_1 = Employee.from_string(emp_string_1)
print(emp_str_1.email)

emp_1 = Employee('Prajesh', 'Ananthan', 5000)
emp_2 = Employee('Ali', 'Ahmad', 3000)

# toString variant of an object
# print(emp_1.__dict__)
