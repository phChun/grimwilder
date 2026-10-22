require "test_helper"

# Pact (pg. 82): a warlock's Eldritch Talents, on top of the one per level.
class CharacterEldritchTalentsTest < ActiveSupport::TestCase
  setup do
    @vex = identities(:pip).characters.create!(name: "Vex", path: "Warlock", brawn: 1, agility: 2, wits: 2, presence: 3, talent_keys: [ "affliction" ])
  end

  test "1 slot to start, +1 at levels 3 and 6; other paths get none" do
    assert_equal({ 1 => 1, 2 => 1, 3 => 2, 4 => 2, 5 => 2, 6 => 3, 7 => 3 }, (1..7).to_h { @vex.level = _1; [ _1, @vex.eldritch_talent_slots ] })
    assert_equal 0, characters(:tibbs).eldritch_talent_slots
    assert_not characters(:tibbs).eldritch_talents?
  end

  test "they don't count against the one per level, and have their own cap" do
    @vex.add_eldritch_talent!("lucky")
    assert @vex.reload.talents_full?, "the level-1 talent is still Affliction alone"
    assert_equal 0, @vex.extra_talents
    assert @vex.eldritch_talents_full?
    assert_raises(ActiveRecord::RecordInvalid) { @vex.add_eldritch_talent!("bulwark") }

    @vex.update!(level: 3, talent_keys: %w[affliction knowing-gaze control])
    @vex.add_eldritch_talent!("bulwark")
    assert_equal %w[lucky bulwark], @vex.reload.eldritch_talent_keys

    @vex.level = 2
    assert_not @vex.valid?, "can't drop below the Eldritch Talents taken"
  end

  test "path talents only: no core, background, prohibited or already-chosen talent" do
    %w[expertise affliction].each do |key|
      @vex.eldritch_talent_keys = [ key ]
      assert_not @vex.valid?, key
    end
    @vex.eldritch_talent_keys = [ Talent.all.find { !_1.group.path? }.key ]
    assert_not @vex.valid?, "a background talent"

    @vex.eldritch_talent_keys = [ "lucky" ]
    @vex.talent_keys = [ "lucky" ]
    assert_not @vex.valid?, "not both at once"
  end

  test "their uses count, and removing one drops its re-skin" do
    @vex.add_eldritch_talent!("lucky")
    assert_includes @vex.pool_uses.map(&:id), "lucky/luck"

    @vex.reskin_talent!("lucky", "name" => "Patron's Favor")
    @vex.remove_eldritch_talent!("lucky")
    assert_empty @vex.reload.eldritch_talent_keys
    assert_empty @vex.talent_skins
  end
end
