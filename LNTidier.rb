require 'nokogiri'

HTML_TEMPLATE = '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title></title><link rel="stylesheet" href="css/main.css"></head><body><div id="main-content"></div></body></html>'

class LNTidier
  def self.tidy(page_source)
    html_doc = Nokogiri::HTML(page_source)
    judgment_doc = self.strip_unnecessary_html(html_doc)

    judgment_doc
  end

  def self.strip_unnecessary_html(html_doc)
    new_html_doc = Nokogiri::HTML(HTML_TEMPLATE)
    insertion_point = new_html_doc.at_xpath('//div[@id="main-content"]')

    main_content = html_doc.at_xpath('//div[@class="contentsOfFile"]')
    main_content.children.each do |c|
      c.parent = insertion_point
    end

    new_html_doc
  end
end
