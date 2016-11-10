from pytube import YouTube
import logger
import os
import winsound
from progressbar import print_status

"""youtube-downloader.py: A Youtube video downloader that is able to download multiple videos from different
                            channels/playlists simultaneously
"""
__author__ = "Prajesh Ananthan"
__copyright__ = "Copyright 2016, Python"
__license__ = "GPL"

# TODO: Launch a simple GUI that able pick up URL entries and download videos accordingly
# TODO: To have flexible approach to download videos at all resolution
# TODO: To download multiple videos simultaneously
# TODO: Import pytube codebase

def main():
    logger.printInfo("Starting Youtube downloader tool...")

    _configfile = 'C:/Users/Prajesh/Swiss-Army-Scripts/Python/Tools/config/links.properties'

    _path = 'videos/'

    _format = 'mp4'

    _quality = '360p'

    openconfigfile(_configfile)

    _links = getlinksfromconfig(_configfile)

    createdirectory(_path)

    downloadvideos(_links, _path, _quality, _format)

    logger.printInfo("Done. Videos downloaded: {}".format(len(_links)))


def openconfigfile(configfile):
    os.startfile(configfile)


def getlinksfromconfig(configfile):
    list = []
    with open(configfile) as f:
        for line in f:
            if line.startswith('#'):
                continue
            list.append(line.strip())
    return list


def createdirectory(directory):
    if not os.path.exists(directory):
        os.makedirs(directory)
        logger.printDebug('{} created!'.format(directory))


def downloadvideos(videos, directory, quality, format):
    video = None
    for vid in videos:
        yt = YouTube(vid)
        logger.printDebug('Downloading => [ {} | {} ]'.format(yt.filename, quality))
        video = yt.get(format, quality)
        video.download(directory, on_progress=print_status)
        winsound.Beep(440, 300)  # frequency, duration
        print()


if __name__ == '__main__':
    main()
