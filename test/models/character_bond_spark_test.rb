require "test_helper"

class CharacterBondSparkTest < ActiveSupport::TestCase
  setup do
    @tibbs, @bram = characters(:tibbs), characters(:bram)
  end

  test "changing a bond toward another PC gives them spark; setting one doesn't" do
    @bram.update!(spark: 0)
    @tibbs.update!(bonds: [ { "character_id" => @bram.id, "to" => "Bram", "bond" => "wary trust" } ])
    assert_equal 0, @bram.reload.spark, "a first bond isn't a change"

    @tibbs.update!(bonds: [ { "character_id" => @bram.id, "to" => "Bram", "bond" => "fierce loyalty" } ])
    assert_equal 1, @bram.reload.spark
    assert_equal "Tibbs's bond with Bram is now fierce loyalty: Bram takes spark.", campaigns(:bramblewood).rolls.last.question

    @tibbs.update!(name: "Tibbs the Bold")
    assert_equal 1, @bram.reload.spark, "only a bond change"
  end
end
