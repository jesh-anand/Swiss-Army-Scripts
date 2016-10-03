import os
import shutil
from logger import printInfo
from logger import printDebug

"""sortFiles.py: A file sorting tools based on keywords"""

__author__ = "Prajesh Ananthan"
__copyright__ = "Copyright 2016, Python"
__license__ = "GPL"

# -- To enable debug logs
DEBUG = True
# -- Insert keywords to capture
KEYWORDS = ('maven', 'spring')

# TODO: Add GUI prompt from user to insert directory entries
# -- Insert target directory
SEARCH_DIRECTORY = 'C:/Users/Prajesh/Swiss-Army-Scripts/Python/Tools/test/'

# -- Insert destination directories
BASE_DIRECTORY = 'C:/Users/Prajesh/Swiss-Army-Scripts/Python/Tools'
MAVEN_DIRECTORY = BASE_DIRECTORY + '/Maven/'
SPRING_DIRECTORY = BASE_DIRECTORY + '/Spring/'
DIRECTORIES = [MAVEN_DIRECTORY, SPRING_DIRECTORY]


def createDirectories():
    reportpath = ''
    try:
        for path in DIRECTORIES:
            reportpath = path
            if not os.path.exists(path):
                os.makedirs(path)
                if DEBUG == True:
                    printDebug(path + ' created!')
        printInfo('All directories successfully created!')
    except OSError:
        if not os.path.isdir(reportpath):
            raise


def sortFiles():
    target = ''
    destination = ''

    try:
        files = os.listdir(SEARCH_DIRECTORY)
        for file in files:
            if KEYWORDS[0] in file:
                target = os.path.abspath('test/' + file)
                destination = MAVEN_DIRECTORY
            elif KEYWORDS[1] in file:
                target = os.path.abspath('test/' + file)
                destination = SPRING_DIRECTORY
            shutil.move(target, destination)
            if DEBUG == True:
                printDebug('Moved {} to {}'.format(file, destination))
        printInfo('Done moving files!')
    except IOError as e:
        printInfo("Unable to open search directory", e)


################################### Main Function ##############################################
if __name__ == "__main__":
    createDirectories()
    sortFiles()
################################# End Main Function ############################################
