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
    end
    assert_equal uses.map(&:id).uniq, uses.map(&:id)
  end

  test "the talents that grant thread per session" do
    assert_equal %w[ according-to-plan bardic-lore reader scout-ahead ], Talent.all.select { _1.uses.any?(&:thread?) }.map(&:key).sort
  end
end
