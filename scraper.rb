require 'open-uri'
require 'nokogiri'
require 'scraperwiki'
require 'mechanize'
require 'csv'
require 'iconv'

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
    @catalog = []
    @id = 1
    configure_scraper
  end

  def call
    add_header
    groups = scan_main_page
    groups.each do |group|
      scan_group(group)
    end
    save
  end

  private

  def add_record(arr)
    arr.map! { |str| Iconv.conv("windows-1251//IGNORE", "utf-8", str) }
    @catalog << arr
    save_to_sqlite(arr)
  end

  def add_header
    @catalog << @headers
  end

  def save
    @catalog.uniq!
    CSV.open('catalog.csv', 'w:windows-1251',
             col_sep: ';',
             headers: true,
             converters: :numeric,
             header_converters: :symbol
            ) do |cat|
      @catalog.each do |row|
        cat << row
      end
    end
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
      item_id = id
      @agent.click(item.content)
      @agent.page.encoding = 'UTF-8'
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
      arr << item_id.to_s
      download_pic("#{item_id}.jpg", @agent.page.at(@tag[:photo])['src'])
      arr << item['href']
    end
    add_record arr
  end

  def id
    @id += 1
  end

  def download_pic(name, url)
    open('pictures/' + name, 'wb') do |file|
      file << open(url).read
    end
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
