class CachedPage < ActiveRecord::Base
  def CachedPage.get_html(url)
    page = CachedPage.where(url: url).first
    if page.nil? || page.valid_until.nil? || page.valid_until < DateTime.now
      content = Net::HTTP.retrieve(url)
      return nil if content.nil?
      #some pages can contain invalid UTF-8 sequences
      #content = content.force_encoding("utf-8").encode("utf-8", "binary", :undef => :replace)
      release_date = Date.parse(Nokogiri::HTML(content).at_css('.release_data .data').content)

      if page.nil?
        page = CachedPage.create(url: url, content: content, valid_until: CachedPage.get_valid_until(release_date))
      else
        page.update(content: content, valid_until: CachedPage.get_valid_until(release_date))
      end
    end
    page.content
  end

  def CachedPage.get_valid_until(release_date)
    days_from_release = (release_date - Date.today).to_i
    if days_from_release < 30
      return Date.today + 1
    elsif days_from_release < 60
      return Date.today + 2
    elsif days_from_release < 365
      return Date.today + 7
    elsif days_from_release < 730
      return Date.today + 14
    elsif days_from_release < 365 * 5
      return Date.today + 30
    end
  end
end
