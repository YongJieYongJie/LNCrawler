require 'open-uri'
require 'nokogiri'
require 'csv'
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
    STDOUT.sync = true
    print 'Fetching LawNet free resources page...'
    main_page = self.fetch_main_page
    puts 'OK'

    print 'Extracting urls to judgment pages...'
    judgment_page_urls = self.extract_judgment_page_urls(main_page)
    puts 'OK'

    judgment_page_urls.each do |url|
      puts 'Extracting judgments from results page...'
      judgments = self.extract_judgments(url)
      puts "found #{judgments.count} judgments"

      print 'Pruning existing judgments...'
      judgments = self.prune_existing_judgments(judgments)
      puts "#{judgments.count} new judgments to download"

      self.download_judgments(judgments) unless judgments.count == 0
    end
  end

  def self.add_to_judgment_index(judgment)
    self.create_download_path_if_needed

    # create new index file with header row if none exist previously
    if (!self.has_index_file)
      begin
        CSV.open(INDEX_FILE_PATH, 'w') do |csv|
          csv << ['Case name', 'Condensed case name', 'Neutral citation']
        end
      rescue Exception => e
        abort("Error creating index file. Please try again.")
      end
    end

    begin
      CSV.open(INDEX_FILE_PATH, 'a') do |csv|
        csv << [judgment[:case_name], judgment.get_condensed_case_name, judgment[:neutral_citation]] 
      end
    rescue
      abort("Error writing to index file. Please try again.")
    end
  end

  def self.prune_existing_judgments(judgments)
    # if no index file exists, there is nothing to be pruned
    return judgments unless self.has_index_file

    existing_judgments = self.get_existing_judgments()
    citations_of_existing_judgments = self.extract_array_of_citations(existing_judgments)

    new_judgments = judgments.select do |j|
      !citations_of_existing_judgments.include?(j[:neutral_citation])
    end

    new_judgments
  end

  def self.extract_array_of_citations(judgments)
    citations = Array.new
    judgments.each do |j|
      citations << j[:neutral_citation]
    end

    citations
  end
  
  def self.has_index_file
    File.exist?(INDEX_FILE_PATH)
  end

  def self.get_existing_judgments
    begin
      index = CSV.read(INDEX_FILE_PATH, :headers => true)
    rescue
      abort("Error opening index file. Please close and try againt")
    end

    existing_judgments = Array.new
    index.each do |csv_row|
      existing_judgments << Judgment.new(
        :case_name => csv_row['Case name'],
        :neutral_citation => csv_row['Neutral citation'],
      )
    end

    existing_judgments
  end

  def self.download_judgments(judgments)
    self.create_download_path_if_needed

    total = judgment.count
    judgments.each_with_index do |j, index|
      puts "Downloading case #{index}/#{total}: #{j.get_condensed_case_name}"
      page_source = open(j[:url], &:read)
      filename = j.get_condensed_case_name.gsub(/[\\\/:\*\?"<>|]/, '_') + '.pdf'
      File.open(DOWNLOAD_PATH + filename, 'w') { |f| f.write(page_source) }
      self.add_to_judgment_index(j)
    end
  end

  def self.create_download_path_if_needed
    Dir.mkdir(DOWNLOAD_PATH) unless File.exist?(DOWNLOAD_PATH)
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
      print "\r...crawling page #{page_no}/#{num_pages}"
      STDOUT.flush
      judgment_page_url = "#{sub_page_url}&_freeresources_WAR_lawnet3baseportlet_page=#{page_no}"
      judgment_page_source = self.fetch_website(judgment_page_url)
      judgments.push (self.get_judgments_from_single_page(judgment_page_source))
    end
    puts ''

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
