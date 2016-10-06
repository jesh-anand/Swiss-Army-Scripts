class Example:
    def __init__(self, **kwargs):
        self.variables = kwargs  # we want it to be a dictionary

    def set_vars(self, k, v):
        self.variables[k] = v

    def get_vars(self, k):
        return self.variables.get(k, None)


value = Example(Name='prajesh', Age=28)

print(value.get_vars('Name'))
