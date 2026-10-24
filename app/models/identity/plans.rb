# The plan an account is on (Plan, config/plans.yml) and what it allows: how
# many active campaigns it may run as GM and play in. Done campaigns don't
# count. Membership checks this on joining or starting a campaign, and
# Campaign::Done on reopening one. Changing someone's plan never closes a
# campaign: an account over its limit just can't start or join another.
module Identity::Plans
  extend ActiveSupport::Concern

  included do
    validates :plan, inclusion: { in: ->(_) { Plan.keys } }
  end

  def current_plan
    Plan.find(plan)
  end

  # Active campaigns where this person has the role ("gm" or "player"),
  # other than except:.
  def active_memberships(role:, except: nil)
    memberships.where(role: role).joins(:campaign).merge(Campaign.active).where.not(campaign_id: except)
  end

  # Whether the plan leaves room for one more active campaign in this role.
  def room_for?(role, except: nil)
    limit = current_plan.limit_for(role)
    limit.nil? || active_memberships(role: role, except: except).count < limit
  end

  def room_to_run?
    room_for?(:gm)
  end

  def room_to_play?
    room_for?(:player)
  end

  # The roles in which this account is past its plan's limit (after an admin
  # moved it to a smaller plan), with how many it has: { "gm" => 3 }.
  def over_plan
    %w[ gm player ].filter_map do |role|
      limit = current_plan.limit_for(role)
      count = active_memberships(role: role).count
      [ role, count ] if limit && count > limit
    end.to_h
  end

  # Why there's no room, said the same way on the campaigns page, the join
  # page and a refused join.
  def plan_limit_message(role)
    plan = current_plan
    limit = plan.limit_for(role)
    names = active_memberships(role: role).includes(:campaign).map { _1.campaign.name }.to_sentence
    allowed = "#{limit} active #{"campaign".pluralize(limit)}"

    if role.to_s == "gm"
      playing = plan.playing ? "" : ", and play in as many as you like"
      "You run #{names}. On the #{plan.name} plan, you can run #{allowed} at a time#{playing}. To start another, mark one done in its settings."
    else
      "You play in #{names}. On the #{plan.name} plan, you can play in #{allowed} at a time. To join another, leave one or wait for its GM to mark it done."
    end
  end
end
