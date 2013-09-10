require 'test_helper'

class Api::ReviewsControllerTest < ActionController::TestCase
  def get_match
    [:method, VCR.request_matchers.uri_without_params(:Timestamp, :Signature)]
  end

  test "invalid comments" do
    VCR.use_cassette('invalid comments', :match_requests_on => get_match) do
      get(:list, id: games(:resistance3).id, type: 'foobar')
      assert_response :missing
    end
  end

  test "comments for invalid game" do
    VCR.use_cassette('invalid comments', :match_requests_on => get_match) do
      get(:list, id: 0, type: 'critics')
      assert_response :missing
    end
  end

  test "critics comments retrieval" do
    VCR.use_cassette('critics comments retrieval', :match_requests_on => get_match) do
      get(:list, id: games(:resistance3).id, type: 'critic')
      assert_response :success
      body = JSON.parse(@response.body)
      assert_equal body.length, 7
      assert_equal body[0]["score"], "100"
      assert_equal body[0]["content"], "Resistance 3 should not be overshadowed by any other game this holiday season as it gives a unique and action-packed adventure from beginning to end."
      assert_equal body[0]["name"], "GamerNode"
      assert_equal body[0]["date"], "Sep 15, 2011"
      assert_equal body[0]["link"], "http://www.gamernode.com/reviews/10965-resistance-3-review/index.html"
    end
  end

  test "users comments retrieval" do
    VCR.use_cassette('critics comments retrieval', :match_requests_on => get_match) do
      get(:list, id: games(:resistance3).id, type: 'user')
      assert_response :success
      body = JSON.parse(@response.body)
      assert_equal body.length, 7
      assert_equal body[0]["score"], "10"
      assert_equal body[0]["content"], "i like it. it is even better than Resistance 2. It is the best part of the series!"
      assert_equal body[0]["name"], "tylerkenobi"
    end
  end
end
