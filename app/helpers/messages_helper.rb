module MessagesHelper
  # Markers only count when they hug a word: "*draws her blade*", not "2 * 3 * 4".
  STRONG = /\*\*(?=\S)(.+?)(?<=\S)\*\*/
  EMPHASIS = /(?<![*\w])\*(?=[^\s*])(.+?)(?<=[^\s*])\*(?![*\w])/

  # A chat line's body (and a journal page's) with a little formatting: **bold**
  # and *italics* (actions and asides, the usual table convention). The text is escaped first, so nothing else
  # the sender typed can become markup; line breaks are kept by the CSS (pre-line).
  def chat_format(text)
    html = ERB::Util.html_escape(text.to_s).to_str
    html = html.gsub(STRONG) { "<strong>#{$1}</strong>" }
    html = html.gsub(EMPHASIS) { "<em>#{$1}</em>" }
    html.html_safe
  end
end
