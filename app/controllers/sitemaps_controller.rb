# /sitemap.xml: the public pages for search engines, from the data, so new
# crucibles are listed as they're added.
class SitemapsController < ApplicationController
  def show
    @crucibles = Crucible.all
    respond_to { _1.xml }
  end
end
