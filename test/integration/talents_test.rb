require "test_helper"

class TalentsTest < ActionDispatch::IntegrationTest
  test "the catalog is public" do
    get talents_path
    assert_response :success
    assert_select "#group-rogue h2", text: "The Rogue"
    assert_select "#talent-expertise .tag", text: "Core"
    assert_select "#talent-eldritch-affinity .tag", text: "Not for Sorcerer"
  end

  test "choose a talent for your character" do
    tibbs = characters(:tibbs)
    sign_in_as identities(:pip)

    get new_character_talent_path(tibbs)
    assert_response :success
    assert_select "section.talent-group:first-of-type h2", text: "The Rogue"
    assert_select "#talent-according-to-plan .tag", text: "Taken"

    post character_talents_path(tibbs), params: { talent: "lucky" }
    assert_redirected_to character_path(tibbs, anchor: "talents")
    assert_includes tibbs.reload.talent_keys, "lucky"

    delete character_talent_path(tibbs, "lucky")
    assert_not_includes tibbs.reload.talent_keys, "lucky"
  end

  test "a core or prohibited talent is refused" do
    tibbs = characters(:tibbs)
    sign_in_as identities(:pip)

    post character_talents_path(tibbs), params: { talent: "sorcery" }
    assert_redirected_to new_character_talent_path(tibbs)
    assert_not_includes tibbs.reload.talent_keys, "sorcery"
  end

  test "only the owner chooses talents" do
    sign_in_as identities(:gwen)

    post character_talents_path(characters(:tibbs)), params: { talent: "lucky" }
    assert_response :not_found
  end
end
