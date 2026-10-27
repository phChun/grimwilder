require "test_helper"

class Grimwild::P6UpdateTest < ActiveSupport::TestCase
  setup do
    @tibbs = characters(:tibbs)
    @tibbs.update_columns(
      talent_keys: %w[according-to-plan], talent_uses: { "according-to-plan/thread" => 1 },
      talent_skins: { "according-to-plan" => { "name" => "The Long Con" } },
      talent_choices: { "expertise" => { "skills" => [ "lying", "duel", "stealth" ] } }
    )
  end

  test "According to Plan becomes Mastermind everywhere it's kept, and skills move to P6's" do
    assert_difference -> { Roll.where(kind: "note").count } do
      Grimwild::P6Update.update!(@tibbs)
    end

    @tibbs.reload
    assert_equal %w[mastermind], @tibbs.talent_keys
    assert_equal({ "mastermind/thread" => 1 }, @tibbs.talent_uses)
    assert_equal "The Long Con", @tibbs.talent_skins.dig("mastermind", "name")
    assert_equal %w[deception stealth], @tibbs.talent_choices.dig("expertise", "skills")
    assert @tibbs.valid?
    assert_equal "According to Plan is now Mastermind (Preview 6). Expertise skills updated for Preview 6: lying → deception; duel dropped (pick a replacement).",
      Roll.where(kind: "note").last.question
  end

  test "running it again changes nothing and posts nothing" do
    Grimwild::P6Update.update!(@tibbs)

    assert_no_difference -> { Roll.count } do
      assert_no_changes -> { @tibbs.reload.attributes } do
        Grimwild::P6Update.update!(@tibbs)
      end
    end
  end

  test "two old skills that became one leave one pick" do
    assert_equal [ %w[parkour], [ "evade → parkour", "traverse → parkour" ] ], Grimwild::P6Update.map_skills(%w[evade traverse])
  end

  test "an unseated character is updated without a note" do
    @tibbs.update_columns(campaign_id: nil)

    assert_no_difference -> { Roll.count } do
      Grimwild::P6Update.update!(@tibbs)
    end
    assert_equal %w[mastermind], @tibbs.reload.talent_keys
  end
end
