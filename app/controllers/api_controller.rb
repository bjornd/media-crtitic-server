require 'net/http'
require 'nokogiri'

class ApiController < ApplicationController
  def lookup
    search_params = {id: params[:id]}

    if params[:id].length == 12
      search_params[:id_type] = 'UPC'
      search_params[:country] = 'us'
    elsif (params[:id].length == 13)
      search_params[:id_type] = 'EAN'
      search_params[:country] = 'uk'
    else
      render :json => '', :status => 404
      return
    end

    if search_params[:id_type] == 'UPC'
      game = Game.where(upc: params[:id]).first
    else
      game = Game.where(ean: params[:id]).first
    end

    if game.nil?
      titles = []
      amazon_info = get_amazon_info(search_params)
      titles.push( amazon_info[:title] ) if !amazon_info.nil?
      ebay_info = get_ebay_info(search_params)
      titles.push( ebay_info[:title] ) if !ebay_info.nil?

      general_info = amazon_info.nil? ? ebay_info : amazon_info

      if !general_info.nil?
        titles.uniq!
        game = get_game_by_title_variants(titles, general_info[:platform])
        if !game.nil?
          game.update(search_params[:id_type].downcase.to_sym => params[:id])
        end
      else
        game = nil
      end
    end

    if game.nil?
      render :json => '', :status => 404
    else
      render :json => get_metacritic_info(game.metacritic_url)
    end
  end

  def retrieve
    data = get_metacritic_info(params[:url])

    if data.nil?
      render :json => '', :status => 404
    else
      render :json => data
    end
  end

  def search
    render :json => search_metacritic(params[:query])
  end

  private

  def retrieve_url(url)
    uri = URI.parse(URI.escape(url.gsub(' ', '+'), '[]'))
    result = Net::HTTP.start(uri.host, uri.port) { |http| http.get(uri.path) }
    return result.code == '200' ? result.body : nil
  end

  def dom_extract(root, values)
    values.each_with_object({}) do |(name, selector), h|
      if selector.is_a?(Array)
        property = selector[1]
        selector = selector[0]
      else
        property = nil
      end
      el = root.at_css(selector)
      if el.nil?
        h[name] = nil
      else
        h[name] = property.nil? ? el.content.strip : el[property]
      end
    end
  end

  def search_metacritic(title, platform=nil)
    search_url = sprintf(
      ApiController::METACRITIC_SEARCH_URL,
      title,
      platform.nil? ? '' : ApiController::METACRITIC_PLATFORMS[platform]
    )
    search_doc = Nokogiri::HTML(retrieve_url(search_url))
    search_doc.css('.search_results .result').map do |result|
      dom_extract(result, {
        title: '.product_title a',
        score: '.metascore',
        platform: '.platform',
        release_date: '.release_date .data',
        publisher: '.publisher .data',
        url: ['.product_title a', 'href']
      })
    end
  end

  def search_metacritic_one(title, platform)
    search_url = sprintf(
      ApiController::METACRITIC_SEARCH_URL,
      title,
      platform.nil? ? '' : ApiController::METACRITIC_PLATFORMS[platform]
    )
    search_doc = Nokogiri::HTML(retrieve_url(search_url))
    search_result = search_doc.css('.search_results .result').select do |result|
      result.at_css('.product_title a').content == title
    end.first
    search_result = search_doc.at_css('.search_results .first_result') if search_result.nil?
    if !search_result.nil?
      search_result.at_css('.product_title a')['href']
    else
      nil
    end
  end

  def get_game_by_title_variants(titles, platform)
    game = Game.where(name: titles, platform: platform).take
    if game.nil?
      url = nil
      title = titles.find do |title|
        url = search_metacritic_one(title, platform)
      end
      game = Game.create(name: title, platform: platform, metacritic_url: url) if url
    end
    game
  end

  def get_amazon_info(params)
    res = Amazon::Ecs.item_lookup(params[:id], {
      id_type: params[:id_type],
      search_index: 'All',
      response_group: 'ItemAttributes,Images,Offers',
      country: params[:country]
    })

    return nil if res.has_error?

    item = res.items[0]
    image = item.get_element('MediumImage')
    item_attributes = item.get_element('ItemAttributes')

    return {
      title: item_attributes.get('Title').gsub(/-.*/, '').gsub(/\(.*?\)/, '').strip,
      platform: item_attributes.get('Platform'),
      image_url: image.get('URL'),
      image_width: image.get('Width'),
      image_height: image.get('Height'),
      #offer: {
      #  name: 'Amazon',
      #  price: item.get_element('OfferSummary').get_element('LowestNewPrice').get('FormattedPrice'),
      #  url: 'http://www.amazon.com/dp/'+item.get('ASIN')
      #}
    }
  end

  EBAY_PLATFORMS = {
    "Sony Playstation 3" => "PlayStation 3",
    "Microsoft Xbox 360" => "Xbox 360"
  }

  def get_ebay_info(params)
    res = Rebay::Shopping.new.find_products({
      :"ProductID.Value" => params[:id],
      :"ProductID.type" => params[:id_type],
      :"IncludeSelector" => 'Details'
    })

    return nil if res.failure?

    details = res.response["Product"]
    reference_id = details["ProductID"].find{ |item| item["Type"] == 'Reference' }["Value"]
    specifics = details["ItemSpecifics"]["NameValueList"]

    platform = specifics.find{ |item| item["Name"] == 'Platform' }["Value"]
    platform = ApiController::EBAY_PLATFORMS[platform] if ApiController::EBAY_PLATFORMS.has_key?(platform)

    return {
      title: specifics.find{ |item| item["Name"] == 'Game' }["Value"].gsub(/-.*/, '').gsub(/\(.*?\)/, '').strip,
      platform: platform,
      image_url: details["StockPhotoURL"] ? details["StockPhotoURL"].sub('_6', '_7') : nil,
      #offer: {
      #  name: 'eBay',
      #  price: '$'+sprintf("%0.02f", res.response["ItemArray"]["Item"][0]["ConvertedCurrentPrice"]["Value"]),
      #  url: 'http://www.ebay.com/ctg/'+reference_id
      #}
    }
  end

  METACRITIC_PLATFORMS = {
    "PlayStation 3" => 1,
    "Xbox 360" => 2,
    "PC" => 3,
    "DS" => 4,
    "3DS" => 16,
    "PlayStation Vita" => 67365,
    "PSP" => 7,
    "Wii" => 8,
    "Wii U" => 68410,
    "PlayStation 2" => 6,
    "PlayStation" => 10,
    "Game Boy Advance" => 11,
    "Xbox" => 12,
    "GameCube" => 13,
    "Nintendo 64" => 14,
    "Dreamcast" => 15
  }

  METACRITIC_BASE_URL = "http://www.metacritic.com"
  METACRITIC_SEARCH_URL = METACRITIC_BASE_URL + "/search/game/%s/results?plats[%s]=1&search_type=advanced"

  def get_metacritic_info(url)
    full_url = ApiController::METACRITIC_BASE_URL + url
    game_page = CachedPage.where(url: url).first
    if game_page.nil?
      game_html = retrieve_url(full_url)
      return nil if game_html.nil?
      #some pages on metacritic contain invalid UTF-8 sequences
      game_html = game_html.force_encoding("utf-8").encode("utf-8", "binary", :undef => :replace)
      game_page = CachedPage.create(url: full_url, content: game_html)
    end

    game_doc = Nokogiri::HTML(game_page.content)

    user_score_el = game_doc.at_css('.product_scores .feature_userscore .count a')

    dom_extract(game_doc, {
      title: '.content_head .product_title a',
      platform: '.content_head .platform a',
      score: '.product_scores .metascore .score_value',
      user_score: '.product_scores .avguserscore .score_value',
      release_date: '.product_data .release_data .data',
      maturity_rating: '.product_details .product_rating .data',
      publisher: '.product_data .publisher .data a',
      critic_reviews_total: '.product_scores .metascore_summary .count a span',
      image_url: ['img.product_image', 'src'],
      image_width: 98,
      image_height: nil
    }).merge({
      metacritic_url: url,
      critic_reviews: game_doc.css('.critic_reviews .review').map do |review|
        data = dom_extract(review, {
          name: '.review_critic a',
          date: '.review_critic .date',
          score: '.review_grade',
          content: '.review_body',
          link: ['.full_review a', 'href']
        })
      end,
      user_reviews: game_doc.css('.user_reviews .review').map do |review|
        if review.at_css('.blurb_etc').nil?
          content = review.at_css('.review_body').content.strip
        else
          content = review.at_css('.blurb_collapsed').content + review.at_css('.blurb_expanded').content
        end
        dom_extract(review, {
          name: '.review_critic a, .review_critic span',
          score: '.review_grade'
        }).merge({
          content: content
        })
      end,
      user_reviews_total: user_score_el.nil? ? nil : user_score_el.content.split(' ', 2).first
    })
  end
end
