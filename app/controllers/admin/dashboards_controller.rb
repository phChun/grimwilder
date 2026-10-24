# Site stats: how many of everything, what's happened this week, and the
# latest sign-ins.
class Admin::DashboardsController < Admin::BaseController
  def show
    week = (7.days.ago..)
    @counts = {
      "Accounts" => Identity.count,
      "Active campaigns" => Campaign.active.count,
      "Done campaigns" => Campaign.done.count,
      "Characters" => Character.count,
      "Sessions open now" => PlaySession.open.count,
      "Rolls this week" => Roll.where(created_at: week).count,
      "Messages this week" => Message.where(created_at: week).count,
      "Sign-ins this week" => Session.where(created_at: week).count
    }
    @sign_ins = Session.includes(:identity).order(created_at: :desc).limit(10)
  end
end
