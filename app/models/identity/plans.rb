# The plan an account is on (Plan, config/plans.yml) and what it allows: how
# many active campaigns it may run as GM and play in. Archived campaigns don't
# count. Membership checks this on joining or starting a campaign, and
# Campaign::Archive on unarchiving one. A plan changes only through
# apply_plan! (the admin now, Stripe later): an account left running more
# campaigns than its plan allows keeps the most recently played going, and the
# rest are held (Membership#held_at), which puts them on hold (Campaign::Hold)
# until the GM swaps one in (keep_playing!), archives one or upgrades.
module Identity::Plans
  extend ActiveSupport::Concern

  included do
    validates :plan, inclusion: { in: ->(_) { Plan.keys } }
  end

  def current_plan
    Plan.find(plan)
  end

  # Active campaigns where this person has the role ("gm" or "player"),
  # other than except:. Held ones don't count: they're on hold.
  def active_memberships(role:, except: nil)
    memberships.unheld.where(role: role).joins(:campaign).merge(Campaign.active).where.not(campaign_id: except)
  end

  # The GM seats held for the plan, in campaigns that aren't archived.
  def held_memberships
    memberships.gm.held.joins(:campaign).merge(Campaign.active)
  end

  # Moves the account to the plan with this key, and holds or unholds its GM
  # seats to fit: with a limit, the most recently played stay unheld (a live
  # session counts as most recent) and the rest are held; without one, nothing
  # is. Archived campaigns and player seats are left alone. Each campaign that
  # goes on hold or comes back says so in its log.
  def apply_plan!(key)
    changing_holds do
      update!(plan: key)
      limit = current_plan.limit_for(:gm)
      seats = gm_seats_by_recent_play
      keep = limit ? seats.first(limit) : seats
      seats.each do |seat|
        if keep.include?(seat) then seat.update!(held_at: nil) if seat.held?
        else seat.update!(held_at: Time.current) unless seat.held?
        end
      end
    end
  end

  # "Play this one": unholds a held GM seat. With no room on the plan, the
  # least recently played seat that isn't held is held in its place, unless
  # that campaign has a session going.
  def keep_playing!(membership)
    raise ArgumentError, "#{membership.campaign.name} isn't on hold for your plan." unless membership.identity_id == id && membership.gm? && membership.held?
    raise ArgumentError, "#{membership.campaign.name} is archived." if membership.campaign.archived?

    changing_holds do
      unless room_to_run?
        swap = gm_seats_by_recent_play.reject(&:held?).last
        raise ArgumentError, "End the session at #{swap.campaign.name} first." if swap.campaign.current_session
        swap.update!(held_at: Time.current)
      end
      membership.update!(held_at: nil)
    end
  end

  # The GM seat keep_playing! would hold to make room, if it needs one.
  def next_to_hold
    gm_seats_by_recent_play.reject(&:held?).last unless room_to_run?
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


  # Why there's no room, said the same way on the campaigns page, the join
  # page and a refused join.
  def plan_limit_message(role)
    plan = current_plan
    limit = plan.limit_for(role)
    names = active_memberships(role: role).includes(:campaign).map { _1.campaign.name }.to_sentence
    allowed = "#{limit} active #{"campaign".pluralize(limit)}"

    if role.to_s == "gm"
      playing = plan.playing ? "" : ", and play in as many as you like"
      "You run #{names}. On the #{plan.name} plan, you can run #{allowed} at a time#{playing}. To start another, archive one."
    else
      "You play in #{names}. On the #{plan.name} plan, you can play in #{allowed} at a time. To join another, leave one or wait for its GM to archive it."
    end
  end

  private
    # GM seats in active campaigns, the most recently played first: a live
    # session, then the latest session started (or the campaign made).
    def gm_seats_by_recent_play
      memberships.gm.joins(:campaign).merge(Campaign.active).includes(:campaign).to_a
        .sort_by { [ _1.campaign.current_session ? 1 : 0, _1.campaign.last_played_at ] }.reverse
    end

    # Runs the change in a transaction, then posts a marker in each campaign
    # that went on hold or came back.
    def changing_holds
      campaigns = memberships.gm.includes(:campaign).map(&:campaign).reject(&:archived?)
      before = campaigns.index_with(&:on_hold?)
      transaction do
        yield
        campaigns.each do |campaign|
          campaign.reload
          next if campaign.on_hold? == before[campaign]
          campaign.post_marker!(campaign.on_hold? ? "#{campaign.name} is on hold: its GM's plan runs fewer campaigns" : "#{campaign.name} is back on", by: self)
        end
      end
    end
end
