# Define here the models for your scraped items
#
# See documentation in:
# https://docs.scrapy.org/en/latest/topics/items.html

import scrapy


class SurfaceCrawllerItem(scrapy.Item):
    # define the fields for your item here like:
    links = scrapy.Field()
    link_texts = scrapy.Field()
    texts = scrapy.Field()
    images = scrapy.Field()
    pass
