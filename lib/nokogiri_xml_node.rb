class Nokogiri::XML::Node
  def extract(values)
    values.each_with_object({}) do |(name, selector), h|
      if selector.is_a?(Array)
        property = selector[1]
        selector = selector[0]
      else
        property = nil
      end
      el = self.at_css(selector)
      if el.nil?
        h[name] = nil
      else
        h[name] = property.nil? ? el.content.strip : el[property]
      end
    end
  end
end