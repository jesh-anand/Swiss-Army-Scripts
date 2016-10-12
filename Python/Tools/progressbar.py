from sys import stdout
from time import clock

"""progressbar.py: A simple progress bar api. Code is forked from pytube repository
                    URL: https://github.com/nficano/pytube

"""


def sizeof(bytes):
    """Takes the size of file or folder in bytes and returns size formatted in
    KB, MB, GB, TB or PB.

    :params bytes:
        Size of the file in bytes
    """
    alternative = [
        (1024 ** 5, ' PB'),
        (1024 ** 4, ' TB'),
        (1024 ** 3, ' GB'),
        (1024 ** 2, ' MB'),
        (1024 ** 1, ' KB'),
        (1024 ** 0, (' byte', ' bytes')),
    ]

    for factor, suffix in alternative:
        if bytes >= factor:
            break
    amount = int(bytes / factor)
    if isinstance(suffix, tuple):
        singular, multiple = suffix
        if amount == 1:
            suffix = singular
        else:
            suffix = multiple
    return "%s%s" % (str(amount), suffix)


def print_status(progress, file_size, start):
    """
    This function - when passed as `on_progress` to `Video.download` - prints
    out the current download progress.

    :params progress:
        The lenght of the currently downloaded bytes.
    :params file_size:
        The total size of the video.
    :params start:
        The time when started
    """

    percent_done = int(progress) * 100. / file_size
    done = int(50 * progress / int(file_size))
    dt = (clock() - start)
    if dt > 0:
        stdout.write("\r  [%s%s][%3.2f%%] %s at %s/s\r " %
                     ('=' * done, ' ' * (50 - done), percent_done,
                      sizeof(file_size), sizeof(progress // dt)))
    stdout.flush()
