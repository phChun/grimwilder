# Site stats: how many of everything, what's happened this week, and who
# signed in last (identities.last_signed_in_at; sessions go on sign-out).
class Admin::DashboardsController < Admin::BaseController
  def show
    week = (7.days.ago..)
    @counts = {
      "Accounts" => Identity.count,
      **Plan.all.to_h { |plan| [ "On #{plan.name}", Identity.where(plan: plan.key).count ] },
      "Active campaigns" => Campaign.active.count,
      "Archived campaigns" => Campaign.archived.count,
      "Characters" => Character.count,
      "Sessions open now" => PlaySession.open.count,
      "Rolls this week" => Roll.where(created_at: week).count,
      "Messages this week" => Message.where(created_at: week).count,
      "Signed in this week" => Identity.where(last_signed_in_at: week).count
    }
    @signed_in = Identity.where.not(last_signed_in_at: nil).order(last_signed_in_at: :desc).limit(10)
  end
end
