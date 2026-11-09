require "test_helper"

class SiteIconsTest < ActionDispatch::IntegrationTest
  test "every page links the icons by a versioned path, so a year-long cache can't keep an old one" do
    get root_path
    version = IconsHelper::SITE_ICON_VERSION
    assert_select "link[rel=icon][href=?][sizes='32x32']", "/favicon.ico?v=#{version}"
    assert_select "link[rel=icon][type='image/svg+xml'][href=?]", "/icon.svg?v=#{version}"
    assert_select "link[rel=apple-touch-icon][href=?]", "/icon.png?v=#{version}"
    %w[ favicon.ico icon.svg icon.png ].each { assert File.exist?(Rails.public_path.join(_1)), "public/#{_1}" }
  end
end
