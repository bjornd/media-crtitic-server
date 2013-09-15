class << Net::HTTP
  def retrieve(url)
    res = Net::HTTP.get_response( URI.parse(URI.escape(url.gsub(' ', '+'), '[]')) )
    return res.code == '200' ? res.body : nil
  end
end