require 'vcr'
require_relative 'LNCrawler.rb'

VCR.configure do |config|
  config.cassette_library_dir = "fixtures/vcr_cassettes"
  config.hook_into :webmock
end

describe LNCrawler do
  it 'fetches LN free resource main page and extract urls to specific pages' do
    VCR.use_cassette('fetch_main_page') do
      page_source = LNCrawler.fetch_main_page
      expect(page_source).to include('<ul class="judgementUpdate">')

      urls = LNCrawler.extract_links_to_sub_pages(page_source)
      expect(urls.count).to eq(3)
    end
  end

  it 'extracts URL of all judgments' do
    VCR.use_cassette('fetch resource paths to judgments') do
      sub_page_url = 'https://www.lawnet.sg:443/lawnet/web/lawnet/free-resources?p_p_id=freeresources_WAR_lawnet3baseportlet&p_p_lifecycle=0&p_p_state=normal&p_p_mode=view&p_p_col_id=column-1&p_p_col_pos=2&p_p_col_count=3&_freeresources_WAR_lawnet3baseportlet_action=supreme'
      resource_paths = LNCrawler.extract_urls_to_judgments(sub_page_url)
      expect(resource_paths.flatten.count).to eq(92)
    end
  end

  xit 'downloads all judgments to json' do

  end
end
