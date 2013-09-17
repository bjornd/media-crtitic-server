class Api::SearchController < ApplicationController
  def search
    search_url = sprintf(
      Api::GamesController::METACRITIC_SEARCH_URL,
      params[:query],
      ''
    )
    search_doc = Nokogiri::HTML(Net::HTTP.retrieve(search_url))
    results = search_doc.css('.search_results .result').map do |result|
      result.extract({
        title: '.product_title a',
        score: '.metascore',
        platform: '.platform',
        release_date: '.release_date .data',
        publisher: '.publisher .data',
        url: ['.product_title a', 'href']
      })
    end

    render json: {success: true, data: results}
  end
end
