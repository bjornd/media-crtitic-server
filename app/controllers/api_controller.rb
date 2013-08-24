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

    amazon_info = get_amazon_info(search_params)
    ebay_info = get_ebay_info(search_params)
    general_info = amazon_info.nil? ? ebay_info : amazon_info

    if general_info.nil?
      render :json => nil, :status => 404
    else
      item_info = get_metacritic_info(general_info[:title], general_info[:platform])
      render :json => item_info.merge(general_info)
    end
  end

  private

  EBAY_PLATFORMS = {
    "Sony Playstation 3" => "PlayStation 3"
  }

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

  METACRITIC_SEARCH_URL = "http://www.metacritic.com/search/game/%s/results?plats[%s]=1&search_type=advanced"

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
        price: item.get_element('OfferSummary').get_element('LowestNewPrice').get('FormattedPrice'),
        url: 'http://www.amazon.com/dp/'+item.get('ASIN')
      }
    }
  end

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
      image_url: details["StockPhotoURL"],
      offer: {
        price: 0,
        url: 'http://www.ebay.com/ctg/'+reference_id
      }
    }
  end

  def get_metacritic_info(title, platform)
    search_url = sprintf(ApiController::METACRITIC_SEARCH_URL, title, ApiController::METACRITIC_PLATFORMS[platform])
    search_results = Net::HTTP.get(URI.parse(URI.escape(search_url.gsub(' ', '+'), '[]')));

    doc = Nokogiri::HTML(search_results)
    first_result = doc.at_css('li.first_result')

    return {
      score: first_result.at_css('.std_score .metascore').content,
      release_date: first_result.at_css('.release_date .data').content,
      maturity_rating: first_result.at_css('.maturity_rating .data').content,
      publisher: first_result.at_css('.publisher .data').content,
      metacritic_url: first_result.at_css('.product_title a')['href']
    }
  end
end
