class Api::OffersController < ApplicationController
  def list_amazon
    game = Game.find(params[:id])

    res = Amazon::Ecs.item_lookup(game.upc, {
      id_type: 'UPC',
      search_index: 'All',
      response_group: 'Offers',
      country: 'us'
    })

    if res.has_error?
      render json: nil, status: 404
    else
      item = res.items[0]
      offers = item.get_element('Offers')
      offer = offers.get_element('Offer')
      render json: [{
        url: 'http://www.amazon.com/dp/'+item.get('ASIN'),
        price: offer.get_element('OfferListing').get_element('Price').get('FormattedPrice'),
        saved: offer.get_element('OfferListing').get_element('AmountSaved').get('FormattedPrice'),
        condition: offer.get_element('OfferAttributes').get('Condition'),
        lowest_new_price: item.get_element('OfferSummary').get_element('LowestNewPrice').get('FormattedPrice'),
        lowest_used_price: item.get_element('OfferSummary').get_element('LowestUsedPrice').get('FormattedPrice'),
        total_new: item.get_element('OfferSummary').get('TotalNew'),
        total_used: item.get_element('OfferSummary').get('TotalUsed')
      }]
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
      render json: nil, status: 404
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
          url: item["ViewItemURLForNaturalSearch"],
          image_url: item["GalleryURL"],
          price: currency + item["CurrentPrice"]["Value"].to_s
        })
      end
      render json: items.select { |item| !item[:type].nil? }
    end
  end
end
