from PIL import Image
import pytesseract
import cv2
import os
import math
import urllib.parse
import requests
import time

from bs4 import BeautifulSoup

# get rid of ligatures !!!!
def cleanUp(text):
    text = text.replace('ﬁ','fi').replace('\n',' ')
    return text

class HQQuestion:

    def __init__(self):
        self.question = None
        self.choices = [None, None, None]
        self.hits = [0, 0, 0]

    def populate(self, img):
        h, w = img.shape
        l, r = 0.12*w, 0.88*w
        # bounds
        qBounds = list(map(lambda x: math.floor(x), [0.18*h, 0.36*h, 0.04*w, 0.96*w]))
        bounds = [list(map(lambda x: math.floor(x), [0.37*h, 0.45*h, l, r]))]
        bounds.append(list(map(lambda x: math.floor(x), [0.47*h, 0.55*h, l, r])))
        bounds.append(list(map(lambda x: math.floor(x), [0.56*h, 0.64*h, l, r])))

        q = img[qBounds[0]:qBounds[1], qBounds[2]:qBounds[3]]
        self.question = cleanUp(pytesseract.image_to_string(q))

        for i in range(3):
            partition = img[bounds[i][0]:bounds[i][1], bounds[i][2]:bounds[i][3]]
            self.choices[i] = cleanUp(pytesseract.image_to_string(partition))

    # google
    def basicSearch(self):
        query = {'q': self.question}
        url = 'https://www.google.com/search?' + urllib.parse.urlencode(query)
        response = requests.get(url)
        soup = BeautifulSoup(response.content, 'lxml')
        for summary in soup.find_all('span', class_='st'):
            for i in range(3):
                self.hits[i] += 2 * (summary.text.lower()).count(self.choices[i].lower())
        try:
            url2 = soup.find("cite").text
            response2 = requests.get(url2)
            soup = BeautifulSoup(response2.content, 'lxml')
            for i in range(3):
                self.hits[i] += 2 * (soup.text.lower()).count(self.choices[i].lower())
        except:
            pass

    def enhancedSearch(self):
        for i in range(3):
            query = {'q': (self.question + ' ' + self.choices[i])}
            url = 'https://www.google.com/search?' + urllib.parse.urlencode(query)
            response = requests.get(url)
            soup = BeautifulSoup(response.content, 'lxml')
            for summary in soup.find_all('span', class_='st'):
                for j in range(3):
                    self.hits[j] += 0.5 * (summary.text.lower()).count(self.choices[j].lower())

    def getResults(self):
        percents = None
        try:
            percents = list(map(lambda x: 100*x/sum(hq.hits), hq.hits))
        except:
            percents = self.hits
        print("\n{}\n".format(self.question))
        for i in range(3):
            print(self.choices[i], "({0:.2f}%)".format(percents[i]))


# Press space and click window to screenshot
os.system("screencapture -i -x -o -w question.png")
start = time.time()
img = cv2.imread('question.png', 0)

# rasterize
img = cv2.threshold(img, 200, 255, cv2.THRESH_BINARY)[1]

hq = HQQuestion()
hq.populate(img)
hq.basicSearch()
hq.enhancedSearch()


hq.getResults()

end = time.time()
print("Time Elapsed: {0:.2f}s\n".format(end - start))


# standard questions
# ranked questions
# reverse questions

def isRanked(question):
    keywords = ['tallest','shortest','oldest','youngest','most recent','first?']

    return False