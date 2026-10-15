module RenderedPageTestHelper
  # ReActionView appends a <template data-herb-region> copy of each reactive
  # template holding every conditional branch, so the browser can re-render.
  # Template contents are inert, so assert_select should only see the live page.
  def document_root_element
    super.tap { |root| root.css("template").each(&:remove) }
  end
end
