# The doctor report gets a kill switch.
#
# Until now /report was either open by URL (REPORT_TOKEN unset) or open to
# whoever held the token. Neither is a switch you can flip before a consult.
# `report_access_until` is that switch: the page answers 404 unless it is in
# the future, and it lapses on its own so a forgotten "on" cannot leave a year
# of health data readable.
#
# `report_token` lets the URL token be rotated without a Render env change
# (which restarts the service); when blank, ENV["REPORT_TOKEN"] is the token.
class AddReportAccessToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :report_access_until, :datetime
    add_column :settings, :report_token, :string
  end
end
