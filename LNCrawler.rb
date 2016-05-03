require 'open-uri'
require 'nokogiri'
require 'HTMLEntities'
#require_relative 'judgment'

class LNCrawler
  DOWNLOAD_PATH = 'judgments_from_lawnet/'
  INDEX_FILE_PATH = DOWNLOAD_PATH + 'index.csv'

  FREE_RESOURCE_URL = 'https://www.lawnet.sg/lawnet/web/lawnet/free-resources'
  JUDGMENT_QUERY = URI.encode_www_form(
    :p_p_id => 'freeresources_WAR_lawnet3baseportlet',
    :p_p_lifecycle => '1',
    :p_p_state => 'normal',
    :p_p_mode => 'view',
    :p_p_col_id => 'column-1',
    :p_p_col_pos => '2',
    :p_p_col_count => '3',
    :_freeresources_WAR_lawnet3baseportlet_action => 'openContentPage',
    :_freeresources_WAR_lawnet3baseportlet_docId => 'JUDGMENT_RESOURCE_LOCATION')
  JUDGMENT_BASE_URL = FREE_RESOURCE_URL + '?' + JUDGMENT_QUERY

  def self.serve_some_justice
    main_page_source = self.fetch_main_page
    sub_page_urls = self.extract_links_to_sub_pages(main_page_source)
    sub_page_url.each do |url|
      resource_paths = self.extract_urls_to_judgments(url)
      self.download_judgments(resource_paths)
    end
  end

  def self.download_judgments(resource_paths)
    resource_paths.each do |rp|
      full_url = JUDGMENT_BASE_URL.gsub('JUDGMENT_RESOURCE_LOCATION', rp)
      uri = URI.parse(full_url)
      page_source = open(uri, &:read)
      File.open('judgment.html', 'wb') { |f| f.write(page_source) }
    end
  end

  def self.fetch_main_page
    page_source = self.fetch_website(FREE_RESOURCE_URL)
  end

  def self.fetch_website(url)
    uri = URI.parse(url)
    page_source = open(uri, &:read)
  end

  def self.extract_links_to_sub_pages(main_page_source)
    urls = Array.new

    main_page_nodes = Nokogiri::HTML(main_page_source)
    urls_nodes = main_page_nodes.xpath('//ul[@class="judgementUpdate"]//a/@href')
    urls_nodes.each { |n| urls << n.content.to_s }

    urls
  end

  def self.extract_urls_to_judgments(sub_page_url)
    sub_page_source = self.fetch_website(sub_page_url)
    sub_page_nodes = Nokogiri::HTML(sub_page_source)
    num_pages = self.get_num_pages(sub_page_nodes) 

    urls = Array.new
    (1..num_pages).each do |page_no|
      judgment_page_url = "#{sub_page_url}&_freeresources_WAR_lawnet3baseportlet_page=#{page_no}"
      judgment_page_source = self.fetch_website(judgment_page_url)
      urls.push (self.get_judgment_url_for_single_page(judgment_page_source))
    end

    urls.flatten
  end

  def self.get_judgment_url_for_single_page(page_source)
    resource_paths = Array.new

    page_doc = Nokogiri::HTML(page_source)
    judgment_nodes = page_doc.xpath('//p[@class="resultsTitle"]/a')

    judgment_nodes.each do |j|
      case_name = j.at_xpath('text()')
      neutral_citation = /(\[[0-9]{4}\] [A-Z]+ [0-9]+)$/.match(case_name)[1]

      unless self.is_downloaded(neutral_citation)
        href_attr = j.at_xpath('@href')
        resource_path = /javascript:viewContent\('(.+)'\)/.match(href_attr)[1]
        resource_paths << resource_path
      end
    end

    resource_paths
  end

  def self.is_downloaded(neutral_citation)
    false
  end

  def self.get_num_pages(sub_page_nodes)
    last_page_onclick_attr = sub_page_nodes.at_xpath('//li[@title="Last page"]/a/@onclick').content
    last_page = /changePageNo\(([0-9]+)\)/.match(last_page_onclick_attr)[1]
    last_page.to_i
  end
end
