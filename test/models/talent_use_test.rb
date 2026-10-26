require "test_helper"

class TalentUseTest < ActiveSupport::TestCase
  test "counts and pools grow at the levels the talent says" do
    inspiration = Talent.find("inspiration").uses.sole
    assert_equal [ 3, 3, 4, 4, 5, 5, 6, 6 ], (0..7).map { inspiration.count_at(_1) }

    wild_shape = Talent.find("wild-shape").uses.sole
    assert wild_shape.pool?
    assert wild_shape.per_scene?
    assert_equal [ 2, 3, 4 ], [ 1, 3, 6 ].map { wild_shape.pool_at(_1) }
    assert_equal "resets each scene", wild_shape.resets
  end

  test "every use is well formed" do
    uses = Talent.all.flat_map(&:uses)
    assert uses.size > 60

    uses.each do |use|
      kinds = [ use.counter?, use.pool?, use.thread? ].count(true)
      assert_equal 1, kinds, "#{use.id} should be exactly one of count, pool or thread"
      assert_includes Talent::Use::PERS, use.per, use.id
      assert use.label.present?, use.id unless use.thread?
      assert_includes Pool::KINDS.keys, use.pool_kind, use.id if use.pool?
      assert use.pool_at(Grimwild::MAX_LEVEL).between?(1, Pool::MAX_SIZE), use.id if use.pool?
      assert use.pool?, "#{use.id}: only a pool drops 1d first" if use.drop_first
      if use.named?
        assert use.counter?, "#{use.id}: only a count's boxes are named"
        assert Talent.find(use.talent_key).choice(use.named_by), "#{use.id} is named by a choice its talent lacks" if use.named_by
      end
      assert use.counter? && use.track.all?(Integer), use.id if use.track?
      assert use.pool?, "#{use.id}: only a pool refills" if use.refill
      assert use.refill == "always" || use.refill.to_i.positive?, use.id if use.refill
    end
    assert_equal uses.map(&:id).uniq, uses.map(&:id)
  end

  test "fixed names, tallies and tracks" do
    bonds = Talent.find("primordial-bonds").uses.sole
    assert_equal [ 4, %w[ Fire Earth Air Water ], "kept until spent" ], [ bonds.count_at(1), bonds.names, bonds.resets ]
    instability = Talent.find("awakened-mind").uses.sole
    assert_equal [ [ 0, 1, 2 ], [ 0, 0, 0, 1, 2 ] ], [ instability.track_at(1), instability.track_at(6) ]
    overloads = Talent.find("mischief-maker").uses.sole
    assert overloads.tally?
    assert_nil overloads.count_at(3)
    assert_equal Float::INFINITY, Talent.find("pact").uses.sole.refills
  end

  test "the talents that grant thread per session" do
    assert_equal %w[ according-to-plan bardic-lore reader scout-ahead ], Talent.all.select { _1.uses.any?(&:thread?) }.map(&:key).sort
  end

  test "the talent pools that drop 1d before rolling" do
    assert_equal %w[ alchemist/potions channel-divinity/major-rite channel-divinity/minor-rite-1 channel-divinity/minor-rite-2 divine-blessing/rite wild-shape/wild-shape ],
      Talent.all.flat_map(&:uses).select(&:drop_first).map(&:id).sort
  end
end
