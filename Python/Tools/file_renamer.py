import os
import sys
from logger import printDebug

""" file_renamer. py: This script renames plain numbered files with meaningful prefixes"""


def main():
    PATH = r"D:\Google Drive\Notes\Book_Summaries\Code_Complete"
    PREFIX = "code_complete"

    os.chdir(PATH)

    for srcTitle in os.listdir(PATH):
        formattedTitle = PREFIX + "_" + srcTitle
        if srcTitle.startswith(formattedTitle):
            continue
        printDebug("Renaming '{}' to '{}'".format(srcTitle, formattedTitle))
        os.rename(srcTitle, formattedTitle)


if __name__ == '__main__':
    main()
