Judgment = Struct.new(:case_name, :neutral_citation, :decision_date, :url) do
  def initialize(args)
    super(*args.values_at(:case_name, :neutral_citation, :decision_date, :url))
  end

  def get_condensed_case_name
    condensed_case_name = case_name.gsub(/ (and|&) ([0-9]? ors|anor|another|others?)\b( (suit|matter|appeal)s?)?/i, '')
    condensed_case_name.gsub!(/( (private|pte|pty|pvt))? (limited|ltd)\b/i, '')
    condensed_case_name.gsub!(/( sdn)? bhd\b/i, '')
    condensed_case_name.gsub!(/public prosecutor/i, 'PP')
    condensed_case_name.gsub!(/Management Corporation Strata Title/i, 'MCST')
    condensed_case_name.gsub!(/Attorney[ -]General/i, 'AG')
    condensed_case_name.gsub!(/ \([^\(]*?(liquidation|executrix|formerly|trading)[^\)]*?\)/i, '')
    condensed_case_name.gsub!(/\s+/, ' ')
    condensed_case_name
  end
end
