Judgment = Struct.new(:case_name, :neutral_citation, :decision_date, :url) do
  def initialize(args)
    super(*args.values_at(:case_name, :neutral_citation, :decision_date, :url))
  end

  def get_condensed_case_name
    condensed_case_name = case_name.gsub(/( (and|&) (an)?other( suit| matter| appeal)?s?| and others| (and|&) [0-9] ors)/i, '')
    condensed_case_name.gsub!(/ private limited| pte limited| pte ltd| pvt ltd| limited| ltd/i, '')
    condensed_case_name.gsub!(/public prosecutor/i, 'PP')
    condensed_case_name.gsub!(/Management Corporation Strata Title/i, 'MCST')
    condensed_case_name.gsub!(/ \([^\(]*?(liquidation|executrix|formerly|trading)[^\)]*?\)/i, '')
    condensed_case_name.gsub!(/\s+/, ' ')
    condensed_case_name
  end
end
