require 'vcr'
require_relative 'LNCrawler.rb'

VCR.configure do |config|
  config.cassette_library_dir = "fixtures/vcr_cassettes"
  config.hook_into :webmock
end

describe LNCrawler do
  it 'fetches LN free resource main page and extract urls to judgment pages' do
    VCR.use_cassette('fetch_main_page') do
      main_page = LNCrawler.fetch_main_page
      urls = LNCrawler.extract_judgment_page_urls(main_page)
      expect(urls.count).to eq(3)
    end
  end

  it 'extracts all judgments in single category' do
    VCR.use_cassette('fetch resource paths to judgments') do
      sub_page_url = 'https://www.lawnet.sg:443/lawnet/web/lawnet/free-resources?p_p_id=freeresources_WAR_lawnet3baseportlet&p_p_lifecycle=0&p_p_state=normal&p_p_mode=view&p_p_col_id=column-1&p_p_col_pos=2&p_p_col_count=3&_freeresources_WAR_lawnet3baseportlet_action=supreme'
      judgments = LNCrawler.extract_judgment_urls(sub_page_url)
      expect(judgments.count).to eq(92)
    end
  end

  it 'downloads all judgments to json' do
    VCR.use_cassette('download judgment') do
      resource_paths = ['/Judgment/18770-SSP.xml']
      LNCrawler.download_judgments(resource_paths)
    end
  end
end
