require 'test_helper'

class Api::OffersControllerTest < ActionController::TestCase
  def get_match
    [:method, VCR.request_matchers.uri_without_params(:Timestamp, :Signature)]
  end

  test "offers for invalid game" do
    VCR.use_cassette('invalid comments', :match_requests_on => get_match) do
      get(:list_amazon, id: 0)
      assert_response :missing
    end
  end

  test "amazon offers retrieval" do
    VCR.use_cassette('amazon offers retrieval', :match_requests_on => get_match) do
      get(:list_amazon, id: games(:resistance3).id)
      assert_response :success
      body = JSON.parse(@response.body)
      assert_equal body.length, 1
      refute_nil body[0]["price"]
      refute_nil body[0]["saved"]
      refute_nil body[0]["condition"]
      refute_nil body[0]["url"]
    end
  end

  test "ebay offers retrieval" do
    VCR.use_cassette('ebay offers retrieval', :match_requests_on => get_match) do
      get(:list_ebay, id: games(:resistance3).id)
      assert_response :success
      body = JSON.parse(@response.body)
      assert body.length > 0
      refute_nil body[0]["title"]
      refute_nil body[0]["type"]
      refute_nil body[0]["start_time"]
      refute_nil body[0]["end_time"]
      refute_nil body[0]["url"]
    end
  end
end
