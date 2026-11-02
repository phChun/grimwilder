module AdminHelper
  # Pagy's count line and page links for an admin list. Pagy builds them as
  # HTML strings, escaping the query values in its links; the only text of ours
  # in them is the noun, which is escaped here.
  def admin_pages_info(pagy, noun)
    pagy.info_tag(item_name: ERB::Util.html_escape(noun.pluralize(pagy.count))).html_safe
  end

  def admin_pages_nav(pagy, noun)
    pagy.series_nav(aria_label: ERB::Util.html_escape("#{noun.capitalize} pages")).html_safe if pagy.last > 1
  end

  # Which release is running (config.x.version and revision, from the image):
  # "v1.4.0 · a1b2c3d", or "a development build" outside a released image.
  def admin_version_line
    version, revision = Rails.configuration.x.version, Rails.configuration.x.revision
    return "a development build" unless version || revision

    safe_join([ tag.strong(version || "an untagged build"), (tag.code(revision) if revision && revision != version) ].compact, " · ")
  end
end
