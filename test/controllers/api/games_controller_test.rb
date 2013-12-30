require 'test_helper'

class Api::GamesControllerTest < ActionController::TestCase
  def get_match
    [:method, VCR.request_matchers.uri_without_params(:Timestamp, :Signature)]
  end

  test "successful lookup" do
    VCR.use_cassette('lookup for resistance 3', :match_requests_on => get_match) do
       get(:lookup, id: '711719817628')
       assert_response :success
       body = JSON.parse(@response.body)
       assert_equal body["success"], true
       assert_equal body["data"]["title"], "Resistance 3"
       assert_equal body["data"]["platform"], "PlayStation 3"
       assert_equal body["data"]["metacritic_url"], "/game/playstation-3/resistance-3"
       assert_equal body["data"]["score"], "83"
    end
  end

  test "lookup for invalid product" do
    VCR.use_cassette('lookup for invalid product', :match_requests_on => get_match) do
       get(:lookup, id: '111111111111')
       assert_response :missing
       body = JSON.parse(@response.body)
       assert_equal body["success"], false
    end
  end

  test "successful game retrieval" do
    VCR.use_cassette('retrieval of resistance 3', :match_requests_on => get_match) do
       get(:retrieve, url: '/game/playstation-3/resistance-3')
       assert_response :success
       body = JSON.parse(@response.body)
       assert_equal body["success"], true
       assert_equal body["data"]["title"], "Resistance 3"
       assert_equal body["data"]["platform"], "PlayStation 3"
       assert_equal body["data"]["metacritic_url"], "/game/playstation-3/resistance-3"
       assert_equal body["data"]["score"], "83"
       assert_equal body["data"]["critic_reviews_total"], "91"
       assert_equal body["data"]["user_score"], "7.7"
    end
  end

  test "retrieval of invalid game" do
    VCR.use_cassette('retrieval of invalid game', :match_requests_on => get_match) do
       get(:retrieve, url: '/foobar')
       assert_response :missing
       body = JSON.parse(@response.body)
       assert_equal body["success"], false
    end
  end
end
