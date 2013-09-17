require 'test_helper'

class Api::SearchControllerTest < ActionController::TestCase
  def get_match
    [:method, VCR.request_matchers.uri_without_params(:Timestamp, :Signature)]
  end

  test "successful search" do
    VCR.use_cassette('search for need for speed shift', :match_requests_on => get_match) do
       get(:search, query: 'need for speed shift')
       assert_response :success
       body = JSON.parse(@response.body)
       assert_equal body["success"], true
       assert_equal body["data"].length, 6
       assert_equal body["data"][0]["title"], 'Need for Speed: Shift'
       assert_equal body["data"][0]["score"], '83'
       assert_equal body["data"][0]["platform"], 'PC'
       assert_equal body["data"][0]["release_date"], 'Sep 15, 2009'
       assert_equal body["data"][0]["publisher"], 'EA Games'
       assert_equal body["data"][0]["url"], '/game/pc/need-for-speed-shift'
    end
  end

  test "search without results" do
    VCR.use_cassette('search without results', :match_requests_on => get_match) do
       get(:search, query: 'foobar')
       assert_response :success
       body = JSON.parse(@response.body)
       assert_equal body["success"], true
       assert_equal body["data"].length, 0
    end
  end
end
