class << Net::HTTP
  def retrieve(url)
    uri = URI.parse(URI.escape(url.gsub(' ', '+'), '[]'))
    result = Net::HTTP.start(uri.host, uri.port) { |http| http.get(uri.path) }
    return result.code == '200' ? result.body : nil
  end
end