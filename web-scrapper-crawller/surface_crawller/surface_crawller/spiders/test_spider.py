import scrapy
from selenium import webdriver
from urllib.parse import urljoin
from ..items import SurfaceCrawllerItem

class TestSpiderReact(scrapy.Spider):
    name = 'test_react'
    start_urls = ['https://dazzling-wisp-5199b3.netlify.app']

    def __init__(self):
        self.driver = webdriver.Chrome()  # or webdriver.Chrome(), etc.

    def parse(self, response):
        self.driver.get(response.url)
        yield scrapy.Request(response.url, callback=self.parse_page2)


    def closed(self, reason):
        self.driver.close()



class TestSpider(scrapy.Spider):
    name = 'test'
    start_urls = ['https://www.selenium.dev']

    def parse(self, response):
        items = SurfaceCrawllerItem()

        links = response.css('a::attr(href)').getall()
        link_texts = response.css('a::text').getall()
        texts = response.xpath('//body//text()').getall()
        images = response.css('img::attr(src)').getall()

        items['links'] = links
        items['link_texts'] = link_texts
        items['texts'] = texts
        items['images'] = images
        yield items

        # for link in links:
        #     absolute_url = urljoin(response.url, link)
        #     yield scrapy.Request(absolute_url, callback=self.parse)