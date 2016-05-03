require 'open-uri'
require 'nokogiri'
require 'HTMLEntities'
require_relative 'judgment.rb'

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
    main_page = self.fetch_main_page
    judgment_page_urls = self.extract_links_to_sub_pages(main_page)
    judgment_page_urls.each do |url|
      judgments = self.extract_judgments(url)
      self.download_judgments(judgments)
    end
  end

  def self.download_judgments(judgments)
    self.create_download_path_if_needed

    judgments.each do |j|
      page_source = open(j[:url], &:read)
      filename = j.get_condensed_case_name.gsub(/[\\\/:\*\?"<>|]/, '_') + '.pdf'
      File.open(DOWNLOAD_PATH + filename, 'wb') { |f| f.write(page_source) }
      self.add_to_judgment_index(j)
    end
  end

  def self.create_download_path_if_needed
    Dir.mkdir(DOWNLOAD_PATH) unless File.exist?(DOWNLOAD_PATH)
  end

  def self.add_to_judgment_index(judgment)
  end

  def self.fetch_main_page
    page_source = self.fetch_website(FREE_RESOURCE_URL)
  end

  def self.fetch_website(url)
    uri = URI.parse(url)
    page_source = open(uri, &:read)
    Nokogiri::HTML(page_source)
  end

  def self.extract_judgment_page_urls(main_page)
    urls = Array.new

    urls_nodes = main_page.xpath('//ul[@class="judgementUpdate"]//a/@href')
    urls_nodes.each { |n| urls << n.content.to_s }

    urls
  end

  def self.extract_judgments(sub_page_url)
    judgment_page = self.fetch_website(sub_page_url)
    num_pages = self.get_num_pages(judgment_page) 

    judgments = Array.new
    (1..num_pages).each do |page_no|
      judgment_page_url = "#{sub_page_url}&_freeresources_WAR_lawnet3baseportlet_page=#{page_no}"
      judgment_page_source = self.fetch_website(judgment_page_url)
      judgments.push (self.get_judgments_from_single_page(judgment_page_source))
    end

    judgments.flatten
  end

  def self.get_judgments_from_single_page(results_page)
    judgments = Array.new

    judgment_nodes = self.get_judgment_nodes(results_page)

    judgment_nodes.each do |j|
      judgments << Judgment.new(
        :case_name => self.parse_case_name(j),
        :neutral_citation => self.parse_neutral_citation(j),
        :url => self.parse_url(j)
      )
    end

    judgments
  end

  def self.get_judgment_nodes(node_set)
    node_set.xpath('//p[@class="resultsTitle"]/a')
  end

  def self.parse_case_name(node)
    node.at_xpath('text()').to_s.strip
  end

  def self.parse_neutral_citation(node)
    /(\[[0-9]{4}\] [A-Z]+ [0-9]+)$/.match(node.at_xpath('text()'))[1]
  end

  def self.parse_url(node)
    href_attr = node.at_xpath('@href')
    resource_path = /javascript:viewContent\('(.+)'\)/.match(href_attr)[1]
    url = JUDGMENT_BASE_URL.gsub('JUDGMENT_RESOURCE_LOCATION', resource_path)
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
