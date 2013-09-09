class CachedPage < ActiveRecord::Base
  def CachedPage.get_html(url)
    page = CachedPage.where(url: url).first
    if page.nil?
      content = Net::HTTP.retrieve(url)
      return nil if content.nil?
      #some pages can contain invalid UTF-8 sequences
      content = content.force_encoding("utf-8").encode("utf-8", "binary", :undef => :replace)
      page = CachedPage.create(url: url, content: content)
    end
    page.content
  end
end
