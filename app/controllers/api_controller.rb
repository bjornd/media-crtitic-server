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
    end

    offers = []
    amazon_info = get_amazon_info(search_params)
    offers.push( amazon_info.delete(:offer) ) if amazon_info
    ebay_info = get_ebay_info(search_params)
    offers.push( ebay_info.delete(:offer) ) if ebay_info
    general_info = amazon_info.nil? ? ebay_info : amazon_info
    general_info[:offers] = offers

    if general_info.nil?
      render :json => nil, :status => 404
    else
      item_info = get_metacritic_info(general_info[:title], general_info[:platform])
      render :json => item_info.merge(general_info)
    end
  end

  private

  def retrieve_url(url)
    return Net::HTTP.get(URI.parse(URI.escape(url.gsub(' ', '+'), '[]')))
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
    "Sony Playstation 3" => "PlayStation 3"
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
      title: specifics.find{ |item| item["Name"] == 'Game' }["Value"],
      platform: platform,
      image_url: details["StockPhotoURL"].sub('_6', '_7'),
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

  def get_metacritic_info(title, platform)
    game = Game.where(name: title, platform: platform).first
    if game.nil?
      search_url = sprintf(ApiController::METACRITIC_SEARCH_URL, title, ApiController::METACRITIC_PLATFORMS[platform])
      search_html = retrieve_url(search_url)
      url = Nokogiri::HTML(search_html).at_css('li.first_result').at_css('.product_title a')['href']
      game = Game.create(name: title, platform: platform, metacritic_url: url)
    end

    game_url = ApiController::METACRITIC_BASE_URL + game.metacritic_url
    game_page = CachedPage.where(url: game_url).first
    if game_page.nil?
      game_html = retrieve_url(game_url)
      game_page = CachedPage.create(url: game_url, content: game_html)
    end

    game_doc = Nokogiri::HTML(game_page.content)

    return {
      score: game_doc.at_css('.product_scores .metascore .score_value').content,
      user_score: game_doc.at_css('.product_scores .avguserscore .score_value').content,
      release_date: game_doc.at_css('.product_data .release_data .data').content,
      maturity_rating: game_doc.at_css('.product_details .product_rating .data').content,
      publisher: game_doc.at_css('.product_data .publisher .data a').content.strip,
      metacritic_url: game.metacritic_url,
      critic_reviews: game_doc.css('.critic_reviews .review').map do |review|
        {
          name: review.at_css('.review_critic a').content,
          date: review.at_css('.review_critic .date').content,
          score: review.at_css('.review_grade').content.strip,
          content: review.at_css('.review_body').content.strip,
          link: review.at_css('.full_review a')['href']
        }
      end,
      user_reviews: game_doc.css('.user_reviews .review').map do |review|
        if review.at_css('.blurb_etc').nil?
          content = review.at_css('.review_body').content.strip
        else
          content = review.at_css('.blurb_collapsed').content + review.at_css('.blurb_expanded').content
        end
        {
          name: review.at_css('.review_critic a').content,
          score: review.at_css('.review_grade').content.strip,
          content: content
        }
      end
    }
  end
end
