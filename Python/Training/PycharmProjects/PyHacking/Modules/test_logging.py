import logging
from time import strftime

print(strftime('%d-%b-%Y %H:%M:%S INFO | {}'.format('Testing 1 2 3')))

logging.basicConfig(format='%(asctime)s %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p')
logging.info('is when this event was logged.')
