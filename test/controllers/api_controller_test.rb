require 'test_helper'

class ApiControllerTest < ActionController::TestCase
  def get_match
    [:method, VCR.request_matchers.uri_without_params(:Timestamp, :Signature)]
  end

  test "successful lookup" do
    VCR.use_cassette('lookup for resistance 3', :match_requests_on => get_match) do
       get(:lookup, id: '711719817628')
       assert_response :success
       body = JSON.parse(@response.body)
       assert_equal body["title"], "Resistance 3"
       assert_equal body["platform"], "PlayStation 3"
       assert_equal body["metacritic_url"], "/game/playstation-3/resistance-3"
       assert_equal body["score"], "83"
    end
  end

  test "lookup for invalid product" do
    VCR.use_cassette('lookup for invalid product', :match_requests_on => get_match) do
       get(:lookup, id: '111111111111')
       assert_response :missing
    end
  end

  test "successful search" do
    VCR.use_cassette('search for need for speed shift', :match_requests_on => get_match) do
       get(:search, query: 'need for speed shift')
       assert_response :success
       body = JSON.parse(@response.body)
       assert_equal body.length, 6

       assert_equal body[0]["title"], 'Need for Speed: Shift'
       assert_equal body[0]["score"], '83'
       assert_equal body[0]["platform"], 'PC'
       assert_equal body[0]["release_date"], 'Sep 15, 2009'
       assert_equal body[0]["publisher"], 'EA Games'
       assert_equal body[0]["url"], '/game/pc/need-for-speed-shift'
    end
  end

  test "search without results" do
    VCR.use_cassette('search without results', :match_requests_on => get_match) do
       get(:search, query: 'foobar')
       assert_response :success
       body = JSON.parse(@response.body)
       assert_equal body.length, 0
    end
  end

  test "successful game retrieval" do
    VCR.use_cassette('retrieval of resistance 3', :match_requests_on => get_match) do
       get(:retrieve, url: '/game/playstation-3/resistance-3')
       assert_response :success
       body = JSON.parse(@response.body)
       assert_equal body["title"], "Resistance 3"
       assert_equal body["platform"], "PlayStation 3"
       assert_equal body["metacritic_url"], "/game/playstation-3/resistance-3"
       assert_equal body["score"], "83"
    end
  end

  test "retrieval of invalid game" do
    VCR.use_cassette('retrieval of invalid game', :match_requests_on => get_match) do
       get(:retrieve, url: '/foobar')
       assert_response :missing
    end
  end
end
