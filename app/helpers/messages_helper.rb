module MessagesHelper
  # Markers only count when they hug a word: "*draws her blade*", not "2 * 3 * 4".
  STRONG = /\*\*(?=\S)(.+?)(?<=\S)\*\*/
  EMPHASIS = /(?<![*\w])\*(?=[^\s*])(.+?)(?<=[^\s*])\*(?![*\w])/
  # A list line: "- milk" or "• milk" (bulleted), "1. milk" or "1) milk" (numbered).
  LIST_ITEM = /\A[ \t]*(?:([-•])|(\d{1,3})[.)])[ \t]+(\S.*)\z/

  # A chat line's body (and a journal page's) with a little formatting: **bold**
  # and *italics* (actions and asides, the usual table convention), and lines
  # starting "- " or "1. " as lists. The text is escaped first, so nothing else
  # the sender typed can become markup; line breaks are kept by the CSS
  # (pre-line), so it goes in a block that may hold a list (a div, not a p).
  def chat_format(text)
    lines = ERB::Util.html_escape(text.to_s).to_str.split("\n", -1)
    blocks = lines.slice_when { |line, following| chat_list_kind(line) != chat_list_kind(following) }
    blocks.map { |block| chat_format_block(block) }.join.html_safe
  end

  private
    def chat_list_kind(line)
      if (item = LIST_ITEM.match(line)) then item[1] ? :ul : :ol
      end
    end

    # A run of list lines becomes one list, with no line breaks around it (the
    # list is a block of its own); anything else keeps its lines.
    def chat_format_block(lines)
      case kind = chat_list_kind(lines.first)
      when :ul, :ol
        items = lines.map { |line| "<li>#{chat_format_inline(LIST_ITEM.match(line)[3])}</li>" }.join
        start = LIST_ITEM.match(lines.first)[2].to_i if kind == :ol
        "<#{kind}#{%( start="#{start}") if start && start != 1}>#{items}</#{kind}>"
      else
        chat_format_inline(lines.join("\n"))
      end
    end

    def chat_format_inline(html)
      html.gsub(STRONG) { "<strong>#{$1}</strong>" }.gsub(EMPHASIS) { "<em>#{$1}</em>" }
    end
end
