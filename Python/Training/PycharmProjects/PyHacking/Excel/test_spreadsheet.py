import openpyxl
import os

day = 16
month = 10
year = 2016
interval = 6
filename = 'Weekly_Outcomes_{}{}{}.xlsx'.format(day, month, year)

wb = openpyxl.Workbook()
sheet = wb.active

for i in range(interval):
    if i == 1:
        i = 0
    wb.create_sheet(index=i, title='{}-{}-{}'.format(day, month, year))
    day += 1

if os.path.exists(filename):
    os.remove(filename)

wb.save(filename)
