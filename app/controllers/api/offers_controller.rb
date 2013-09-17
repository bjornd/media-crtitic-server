class Api::OffersController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound do |exception|
    render json: {success: false}, status: 404
  end

  AMAZON_CATEGORIES = {
    "PlayStation 3" => '14210751',
    "Xbox 360" => '14220161',
    "PC" => '229575',
    "DS" => '11075831',
    "3DS" => '2622269011',
    "PlayStation Vita" => '3010556011',
    "PSP" => '11075221',
    "Wii" => '14218901',
    "Wii U" => '3075112011',
    "PlayStation 2" => '301712',
    "PlayStation" => '229773',
    "Game Boy Advance" => '541020',
    "Xbox" => '537504',
    "GameCube" => '541022',
    "Nintendo 64" => '229763',
    "Dreamcast" => '1065996'
  }

  def list_amazon
    game = Game.find(params[:id])

    if game.upc.nil?
      update_ids(game)
    end

    if !game.upc.nil?
      res = Amazon::Ecs.item_lookup(game.upc, {
        id_type: 'UPC',
        search_index: 'VideoGames',
        response_group: 'ItemAttributes,Offers,Images',
        country: 'us'
      })

      if res.has_error?
        render json: {success: true, data: []}
      else
        result = get_amazon_best_result(res.items, game.name)
        render json: {
          success: true,
          data: [extract_amazon_params(result, {
            title: 'ItemAttributes Title',
            price: 'Offers Offer OfferListing Price FormattedPrice',
            saved: 'Offers Offer OfferListing AmountSaved FormattedPrice',
            condition: 'Offers Offer OfferAttributes Condition',
            image_url: 'MediumImage URL',
            image_width: 'MediumImage Width',
            image_height: 'MediumImage Height',
            lowest_new_price: 'OfferSummary LowestNewPrice FormattedPrice',
            lowest_used_price: 'OfferSummary LowestUsedPrice FormattedPrice',
            total_new: 'OfferSummary TotalNew',
            total_used: 'OfferSummary TotalUsed'
          }).merge({
            url: 'http://www.amazon.com/dp/'+result.get('ASIN'),
          })]
        }
      end
    else
      render json: {success: true, data: []}
    end
  end

  CURRENCIES = {
    'USD' => '$',
    'GBP' => '£'
  }

  def list_ebay
    game = Game.find(params[:id])

    res = Rebay::Shopping.new.find_products({
      :"ProductID.Value" => game.upc,
      :"ProductID.type" => 'UPC',
      :"IncludeSelector" => 'Details'
    })

    if res.failure?
      render json: {success: false}, status: 404
    else
      items = res.response["ItemArray"]["Item"].map do |item|
        if item["ListingType"] == 'Chinese'
          data = {
            type: 'auction',
            bid_count: item["BidCount"]
          }
        elsif item["ListingType"] == 'Chinese'
          data = {
            type: 'buyitnow'
          }
        else
          data = {}
        end
        currency = Api::OffersController::CURRENCIES[item["CurrentPrice"]["CurrencyID"]]
        currency = item["CurrentPrice"]["CurrencyID"] if currency.nil?
        data.merge({
          title: item["Title"],
          start_time: item["StartTime"],
          end_time: item["EndTime"],
          time_left: item["TimeLeft"],
          url: item["ViewItemURLForNaturalSearch"],
          image_url: item["GalleryURL"],
          price: currency + item["CurrentPrice"]["Value"].to_s
        })
      end
      render json: {success: true, data: items.select { |item| !item[:type].nil? }}
    end
  end

  private

  def get_amazon_best_result(items, name)
    min_dist = 1024 #number greater than any game title
    result = nil
    items.each do |item|
      title = item.get_element('ItemAttributes').get('Title')
      title = title.gsub(/\u00a0/, ' ').gsub(//, '').gsub(/\(.*?\)| -.*|\[.*?\]/, '').strip
      dist = Text::Levenshtein.distance(title, name)
      if dist < min_dist
        result = item
        min_dist = dist
      end
    end
    result
  end

  def update_ids(game)
    res = Amazon::Ecs.item_search(game.name, {
      country: 'us',
      sort: 'relevancerank',
      browse_node: Api::OffersController::AMAZON_CATEGORIES[game.platform],
      response_group: 'ItemAttributes'
    })

    result = get_amazon_best_result(res.items, game.name)
    item_attrs = result.get_element('ItemAttributes')
    update_params = {}
    update_params[:ean] = item_attrs.get('EAN') if item_attrs.get('EAN')
    update_params[:upc] = item_attrs.get('UPC') if item_attrs.get('UPC')
    game.update(update_params) if !update_params.empty?
  end

  def extract_amazon_params(root, params)
    result = {}
    params.each do |key, value|
      node_names = value.split(' ')
      last_node = node_names.pop
      el = root.get_element(node_names.join(' '))
      result[key] = el.nil? ? nil : el.get(last_node)
    end
    result
  end
end
