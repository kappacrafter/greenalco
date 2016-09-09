require 'open-uri'
require 'nokogiri'
require 'scraperwiki'
require 'mechanize'

class Parser
  attr_accessor :url, :tag, :doc, :headers

  def initialize
    @tag = Hash.new
    @tag[:main_category] = '.box-category ul li a'
    @tag[:item] = '.product-grid .name a'

    @tag[:name] = 'h1'
    @tag[:category] = '.breadcrumb a' #second one is a categori
    @tag[:currency] = '.price span' #needs regexp
    @tag[:currency2] = '.price' #needs regexp
    @tag[:price] = '.price span' #needs regexp
    @tag[:price2] = '.price' #needs regexp
    @tag[:description] = '.tab-content'
    @tag[:photo] = '.image a img'

    @url = 'http://greenalco.ru'
    @agent = Mechanize.new
    @headers = %w(name paramsynonym category currency price description photos url)
    configure_scraper
  end

  def call
    groups = scan_main_page
    groups.each do |group|
      scan_group(group)
    end
  end

  private

  def add_record(arr)
    save_to_sqlite(arr)
  end

  def scan_main_page
    scan_menu
  end

  def scan_menu
    p 'Scanning main menu'
    @page = @agent.get(@url)
    groups = Hash.new
    @page.search(@tag[:main_category]).each do |row|
      groups[row.content] = row['href']
    end

    groups
  end

  def scan_group(group)
    p "Scanning group #{group[0]}"
    @agent.transact do
      @agent.click(group[0])
      @agent.page.search(@tag[:item]).each do |item|
        scan_item item
      end
    end
  end

  def scan_item(item)
    arr = []
    @agent.transact do
      @agent.click(item.content)
      arr << @agent.page.at(@tag[:name]).content
      arr << item['href'][/.*\/(.*)\.html/, 1]
      arr << @agent.page.search(@tag[:category])[1].content

      unless @agent.page.at(@tag[:price]).nil?
        arr << @agent.page.at(@tag[:currency]).content.split(' ')[1]
        arr << @agent.page.at(@tag[:price]).content.split(' ')[0]
      else
        arr << @agent.page.at(@tag[:currency2]).content.split(' ')[1]
        arr << @agent.page.at(@tag[:price2]).content.split(' ')[0]
      end

      arr << @agent.page.at(@tag[:description]).content.strip.chomp
      arr << @agent.page.at(@tag[:photo])['src']
      arr << item['href']
    end
    save_to_sqlite arr
  end

  def configure_scraper
    ScraperWiki.config = { db: 'data.sqlite', default_table_name: 'data' }
  end

  def save_to_sqlite(arr)
    p "Saving #{arr[0]}"
    ScraperWiki.save_sqlite(["url"], Hash[@headers.zip arr])
  end
end

Parser.new.call
