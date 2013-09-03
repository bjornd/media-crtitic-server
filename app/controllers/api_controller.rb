require 'net/http'
require 'nokogiri'

class ApiController < ApplicationController
  def lookup
    search_params = {id: params[:id]}

    if params[:id].length === 12
      search_params[:id_type] = 'UPC'
      search_params[:country] = 'us'
    elsif (params[:id].length === 13)
      search_params[:id_type] = 'EAN'
      search_params[:country] = 'uk'
    else
      render :json => '', :status => 404
      return
    end

    offers = []
    titles = []
    amazon_info = get_amazon_info(search_params)
    if !amazon_info.nil?
      offers.push( amazon_info.delete(:offer) )
      titles.push( amazon_info[:title] )
    end
    ebay_info = get_ebay_info(search_params)
    if !ebay_info.nil?
      offers.push( ebay_info.delete(:offer) )
      titles.push( ebay_info[:title] )
    end

    general_info = amazon_info.nil? ? ebay_info : amazon_info

    if !general_info.nil?
      general_info[:offers] = offers
      titles.uniq!
      game = get_game(titles, general_info[:platform])
    else
      game = nil
    end

    if game.nil?
      render :json => '', :status => 404
    else
      general_info[:title] = game.name
      item_info = get_metacritic_info(game)
      render :json => item_info.merge(general_info)
    end
  end

  def search
    render :json => search_metacritic(params[:query])
  end

  private

  def retrieve_url(url)
    return Net::HTTP.get(URI.parse(URI.escape(url.gsub(' ', '+'), '[]')))
  end

  def search_metacritic(title, platform=nil)
    search_url = sprintf(
      ApiController::METACRITIC_SEARCH_URL,
      title,
      platform.nil? ? '' : ApiController::METACRITIC_PLATFORMS[platform]
    )
    search_doc = Nokogiri::HTML(retrieve_url(search_url))
    search_doc.css('.search_results .result').map do |result|
      {
        title: result.at_css('.product_title a').content,
        score: result.at_css('.metascore').content,
        platform: result.at_css('.platform').content,
        release_date: result.at_css('.release_date .data').content,
        publisher: result.at_css('.publisher .data').content
      }
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

  def get_game(titles, platform)
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
      offer: {
        name: 'Amazon',
        price: item.get_element('OfferSummary').get_element('LowestNewPrice').get('FormattedPrice'),
        url: 'http://www.amazon.com/dp/'+item.get('ASIN')
      }
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
      offer: {
        name: 'eBay',
        price: '$'+sprintf("%0.02f", res.response["ItemArray"]["Item"][0]["ConvertedCurrentPrice"]["Value"]),
        url: 'http://www.ebay.com/ctg/'+reference_id
      }
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

  def get_metacritic_info(game)
    game_url = ApiController::METACRITIC_BASE_URL + game.metacritic_url
    game_page = CachedPage.where(url: game_url).first
    if game_page.nil?
      game_html = retrieve_url(game_url)
      #some pages on metacritic contain invalid UTF-8 sequences
      game_html = game_html.force_encoding("utf-8").encode("utf-8", "binary", :undef => :replace)
      game_page = CachedPage.create(url: game_url, content: game_html)
    end

    game_doc = Nokogiri::HTML(game_page.content)

    score_el = game_doc.at_css('.product_scores .metascore .score_value')
    maturity_rating_el = game_doc.at_css('.product_details .product_rating .data')

    return {
      score: score_el.nil? ? nil : score_el.content,
      user_score: game_doc.at_css('.product_scores .avguserscore .score_value').content,
      release_date: game_doc.at_css('.product_data .release_data .data').content,
      maturity_rating: maturity_rating_el.nil? ? nil : maturity_rating_el.content,
      publisher: game_doc.at_css('.product_data .publisher .data a').content.strip,
      metacritic_url: game.metacritic_url,
      critic_reviews: game_doc.css('.critic_reviews .review').map do |review|
        link = review.at_css('.full_review a')
        date = review.at_css('.review_critic .date')
        {
          name: review.at_css('.review_critic a').content,
          date: date.nil? ? nil : date.content,
          score: review.at_css('.review_grade').content.strip,
          content: review.at_css('.review_body').content.strip,
          link: link.nil? ? nil : link['href']
        }
      end,
      critic_reviews_total: game_doc.at_css('.product_scores .metascore_summary .count a span').content,
      user_reviews: game_doc.css('.user_reviews .review').map do |review|
        if review.at_css('.blurb_etc').nil?
          content = review.at_css('.review_body').content.strip
        else
          content = review.at_css('.blurb_collapsed').content + review.at_css('.blurb_expanded').content
        end
        {
          name: review.at_css('.review_critic a, .review_critic span').content,
          score: review.at_css('.review_grade').content.strip,
          content: content
        }
      end,
      user_reviews_total: game_doc.at_css('.product_scores .feature_userscore .count a').content.split(' ', 2).first
    }
  end
end
