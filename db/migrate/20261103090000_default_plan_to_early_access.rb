# New accounts start on Early access (no limits) until paid plans begin.
# Accounts already on a plan keep it.
class DefaultPlanToEarlyAccess < ActiveRecord::Migration[8.2]
  def change
    change_column_default :identities, :plan, from: "free", to: "early_access"
  end
end
