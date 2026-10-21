require "test_helper"

# Anything that fails to save says so in a toast (shared/_toasts), wherever the
# page is scrolled.
class FailureToastsTest < ActionDispatch::IntegrationTest
  setup do
    @tibbs = characters(:tibbs)
    sign_in_as identities(:pip)
  end

  test "an alert is a toast, not a line at the top of the page" do
    post character_condition_roll_path(@tibbs, 0)
    follow_redirect!

    assert_select ".toasts .toast[role=alert][data-turbo-permanent][id^='toast-'] .toast__message", flash[:alert]
    assert_select ".flash--alert", 0
  end

  test "a save nothing else caught goes back with a toast, not an error page" do
    @tibbs.update_column(:name, "")

    patch character_damage_path(@tibbs), params: { character: { bloodied: true } }, headers: { "HTTP_REFERER" => character_url(@tibbs) }
    assert_redirected_to character_url(@tibbs)
    assert_response :see_other
    assert_equal "That didn't save. Name can't be blank", flash[:alert]
    assert_not @tibbs.reload.bloodied?
  end

  test "adding a condition with no name says so" do
    post character_conditions_path(@tibbs), params: { condition: "  ", dice: "3" }
    assert_redirected_to character_path(@tibbs, anchor: "damage")
    assert_equal "Name the condition to add it.", flash[:alert]
    assert_empty @tibbs.reload.conditions
  end

  test "a form sent with something missing goes back with a toast, not a Bad Request" do
    post character_talents_path(@tibbs), params: {}, headers: { "HTTP_REFERER" => new_character_talent_url(@tibbs) }
    assert_redirected_to new_character_talent_url(@tibbs)
    assert_response :see_other
    assert_equal "That didn't save. Fill in talent and try again.", flash[:alert]
  end

  test "every page can make toasts in the browser, and has none to begin with" do
    get character_path(@tibbs)
    assert_match %r{<template data-toasts-target="template"[^>]*>.*class="toast"}m, response.body, "a toast to copy (template contents aren't in the parsed page)"
    assert_select ".toasts > .toast", 0
  end
end
