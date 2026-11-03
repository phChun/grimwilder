require "test_helper"

class PlanTest < ActiveSupport::TestCase
  test "every plan is well formed" do
    assert_equal Plan.keys.uniq, Plan.keys
    assert_includes Plan.keys, "free"
    Plan.all.each do |plan|
      assert plan.name.present?, plan.key
      [ plan.running, plan.playing ].each { assert _1.nil? || (_1.is_a?(Integer) && _1.positive?), plan.key }
    end
  end

  test "free runs one active campaign and plays in any number; early access, patron and tester have no limits" do
    assert_equal 1, Plan.find(:free).limit_for(:gm)
    assert_nil Plan.find(:free).limit_for(:player)
    assert_nil Plan.find(:early_access).limit_for(:gm)
    assert_nil Plan.find(:early_access).limit_for(:player)
    assert_nil Plan.find(:patron).limit_for(:gm)
    assert_nil Plan.find(:tester).limit_for(:gm)
    assert_raises(ActiveRecord::RecordNotFound) { Plan.find(:gold) }
  end
end
