module SessionTestHelper
  # Signs in the way a person does: ask for a code, then redeem it.
  def sign_in_as(identity)
    post session_path, params: { email_address: identity.email_address }
    post session_magic_link_path, params: { code: MagicLink.order(:id).last.code }
    assert cookies[:session_token].present?, "expected a session cookie after signing in"
  end

  def sign_out
    delete session_path
  end
end
