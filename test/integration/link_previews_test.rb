require "test_helper"

class LinkPreviewsTest < ActionDispatch::IntegrationTest
  test "every page has Open Graph and Twitter card tags with the preview image" do
    get root_path
    assert_select "meta[property='og:title'][content=Grimwilder]"
    assert_select "meta[property='og:image'][content*='og-image']"
    assert_select "meta[name='twitter:card'][content=summary_large_image]"
    assert_select "link[rel=canonical][href=?]", root_url
    assert_select "meta[name=description][content*='Grimwild: Community Edition']", 1
  end

  test "a crucible's preview describes that crucible" do
    get crucible_path("treasure")
    assert_select "meta[property='og:title'][content='Finding treasure']"
    assert_select "meta[property='og:description'][content^='What a treasure turns out to be']"
  end

  test "an invite link's preview names the campaign and its GM, and no more" do
    campaign = campaigns(:bramblewood)
    get join_path(campaign.join_code)
    assert_select "meta[property='og:title'][content=?]", "Join #{campaign.name}"
    assert_select "meta[property='og:description'][content=?]", "Run by #{campaign.gms.first.display_name}. Join to sit at this Grimwild table as a player."
  end

  test "the sitemap lists the public pages and every crucible" do
    get sitemap_path
    assert_response :success
    assert_equal "application/xml", response.media_type
    locs = Nokogiri::XML(response.body).remove_namespaces!.xpath("//loc").map(&:text)
    assert_includes locs, root_url
    assert_includes locs, talents_url
    assert_includes locs, crucible_url("potion")
    assert_equal Crucible.all.size + 4, locs.size
    assert locs.none? { _1.include?("/campaigns") }
  end

  test "robots.txt keeps crawlers off private pages and invite links, and points at the sitemap" do
    robots = Rails.root.join("public/robots.txt").read
    assert_includes robots, "Disallow: /join/"
    assert_includes robots, "Disallow: /admin"
    assert_includes robots, "Sitemap: https://grimwilder.com/sitemap.xml"
  end
end
