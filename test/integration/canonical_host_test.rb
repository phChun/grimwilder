require "test_helper"

class CanonicalHostTest < ActionDispatch::IntegrationTest
  test "www redirects to the bare domain, keeping the path" do
    host! "www.grimwilder.com"

    get "/campaigns/1/pools?x=1"
    assert_redirected_to "https://grimwilder.com/campaigns/1/pools?x=1"
  end
end
