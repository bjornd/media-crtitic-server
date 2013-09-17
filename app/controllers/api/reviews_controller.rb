class Api::ReviewsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound do |exception|
    render json: {success: false}, status: 404
  end

  def list
    if params[:type] == 'critic' || params[:type] == 'user'
      game = Game.find(params[:id])
      url = Api::GamesController::METACRITIC_BASE_URL + game.metacritic_url
      document = Nokogiri::HTML(CachedPage.get_html(url))

      if params[:type] == 'critic'
        data = document.css('.critic_reviews .review').map do |review|
          data = review.extract({
            name: '.review_critic a',
            date: '.review_critic .date',
            score: '.review_grade',
            content: '.review_body',
            link: ['.full_review a', 'href']
          })
        end
      else
        data = document.css('.user_reviews .review').map do |review|
          if review.at_css('.blurb_etc').nil?
            content = review.at_css('.review_body').content.strip
          else
            content = review.at_css('.blurb_collapsed').content + review.at_css('.blurb_expanded').content
          end
          review.extract({
            name: '.review_critic a, .review_critic span',
            score: '.review_grade'
          }).merge({
            content: content
          })
        end
      end

      render json: {success: true, data: data}
    else
      render json: {success: false}, status: 404
    end
  end
end
