require "test_helper"

class FeedbackFlowTest < ActionDispatch::IntegrationTest
  test "an admin turns feedback on for an account, which then sends some from the page it's on" do
    sign_in_as identities(:ada)
    post admin_identity_feedback_access_path(identities(:pip))
    assert identities(:pip).reload.feedback_enabled?
    get admin_identities_path
    assert_select "button[aria-label=?]", "Feedback is on for Pip: turn it off"
    sign_out

    sign_in_as identities(:pip)
    get campaign_path(campaigns(:bramblewood))
    assert_select "a.feedback-button[href=?][data-turbo-frame=modal]", new_feedback_path(path: campaign_path(campaigns(:bramblewood)))

    get new_feedback_path(path: campaign_path(campaigns(:bramblewood)))
    assert_select "turbo-frame#modal .feedback-form__path", campaign_path(campaigns(:bramblewood))
    assert_select "input[type=hidden][name='feedback[path]'][value=?]", campaign_path(campaigns(:bramblewood))

    post feedbacks_path, params: { feedback: { path: campaign_path(campaigns(:bramblewood)), body: "Where do I roll?" } }, headers: { "User-Agent" => "TestBrowser" }
    assert_redirected_to campaign_path(campaigns(:bramblewood))
    assert_equal "Thanks for the feedback.", flash[:notice]
    feedback = Feedback.sole
    assert_equal [ identities(:pip), "Where do I roll?", "campaigns#show", "TestBrowser" ], [ feedback.identity, feedback.body, feedback.route, feedback.user_agent ]

    post feedbacks_path, params: { feedback: { path: "//evil.example", body: "Hi" } }
    assert_response :unprocessable_entity
  end

  test "without it on, there's no button and no form" do
    sign_in_as identities(:pip)
    get campaign_path(campaigns(:bramblewood))
    assert_select ".feedback-button", 0
    get new_feedback_path
    assert_response :not_found
    post feedbacks_path, params: { feedback: { path: "/", body: "Hi" } }
    assert_response :not_found
  end

  test "admins read it, search it, copy it as Markdown and remove it; nobody else sees it" do
    identities(:pip).feedbacks.create!(path: "/roll", body: "Dice are slow.")
    identities(:gwen).feedbacks.create!(path: "/talents", body: "Love the catalog.")

    sign_in_as identities(:pip)
    get admin_feedbacks_path
    assert_response :not_found
    sign_out

    sign_in_as identities(:ada)
    get admin_feedbacks_path
    assert_select ".admin-feedback__item", 2
    assert_select "textarea#feedback-markdown", /## 1\. \/talents.*## 2\. \/roll/m

    get admin_feedbacks_path(q: "dice")
    assert_select ".admin-feedback__item", 1
    assert_select "textarea#feedback-markdown", /Dice are slow/
    assert_select "textarea#feedback-markdown", { text: /Love the catalog/, count: 0 }

    delete admin_feedback_path(Feedback.find_by!(path: "/roll"))
    assert_equal [ "/talents" ], Feedback.pluck(:path)

    delete admin_identity_feedback_access_path(identities(:pip))
    assert_not identities(:pip).reload.feedback_enabled?
  end
end
