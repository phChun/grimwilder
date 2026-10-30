# Search for the admin lists (accounts, interested, campaigns): `search(scope,
# *columns)` keeps the rows where any column contains ?q=, ignoring case.
# Paging is pagy's (Pagy::Method in Admin::BaseController); its links keep ?q=.
module AdminSearch
  extend ActiveSupport::Concern

  PER_PAGE = 50

  included do
    helper_method :search_query
  end

  private
    def search_query
      params[:q].to_s.strip
    end

    def search(scope, *columns)
      return scope if search_query.empty?

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(search_query.downcase)}%"
      scope.where(columns.map { "LOWER(#{_1}) LIKE :pattern" }.join(" OR "), pattern: pattern)
    end
end
