require 'net/http'
require 'nokogiri'

class ApiController < ApplicationController
  def lookup
    if (params[:id].length === 12)
      id_type = 'UPC'
    elsif (params[:id].length === 13)
      id_type = 'EAN'
    end

    res = Amazon::Ecs.item_lookup(params[:id], {
      id_type: id_type,
      search_index: 'All',
      response_group: 'ItemAttributes,Images,Offers'
    })

    puts res.doc

    item = res.items[0]
    image = item.get_element('MediumImage')
    item_attributes = item.get_element('ItemAttributes')

    title = item_attributes.get('Title')
    platform = item_attributes.get('Platform')

    item_info = get_metacritic_info(title, platform)

    render :json => item_info.merge({
      title: title,
      platform: platform,
      image_url: image.get('URL'),
      image_width: image.get('Width'),
      image_height: image.get('Height'),
      amazon_id: item.get('ASIN'),
      amazon_price: item.get_element('OfferSummary').get_element('LowestNewPrice').get('FormattedPrice')
    })
  end

  private

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

  def get_metacritic_info(title, platform)
    search_url = sprintf(ApiController::METACRITIC_SEARCH_URL, title, ApiController::METACRITIC_PLATFORMS[platform])
    search_results = Net::HTTP.get(URI.parse(URI.escape(search_url.sub(' ', '+'), '[]')));

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
