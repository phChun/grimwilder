xml.instruct!
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  [ root_url, roll_url, crucibles_url, talents_url, *@crucibles.map { crucible_url(_1) } ].each do |url|
    xml.url { xml.loc url }
  end
end
