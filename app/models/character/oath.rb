# Oathbreaker (pg. 69): a Paladin who breaks two tenets loses Oathsworn and
# takes the Adventurer's Talented in its place, with its extra talents.
# Redemption, by ritual or mythic deed, restores Oathsworn and keeps one talent
# gained while oathbroken; it's possible only once. The owner marks both.
module Character::Oath
  OATHSWORN = "oathsworn"
  TALENTED = "talented"

  def oathbroken?
    oathbroken_at.present? && path == "Paladin"
  end

  def oath_redeemed?
    oath_redeemed_at.present?
  end

  def can_break_oath?
    path == "Paladin" && !oathbroken? && !level.to_i.zero?
  end

  def can_redeem_oath?
    oathbroken? && !oath_redeemed?
  end

  # The one talent a redeemed Paladin keeps from their time oathbroken.
  def oath_kept_talents
    oath_redeemed? && !oathbroken? && path == "Paladin" ? 1 : 0
  end

  def break_oath!(by:)
    raise ArgumentError, "Only a Paladin sworn to an oath can break it." unless can_break_oath?

    update!(oathbroken_at: Time.current)
    note_oath!("#{short_name} breaks their oath: Oathsworn gives way to Talented (Oathbreaker).", by: by)
  end

  def redeem_oath!(by:)
    raise ArgumentError, "Redemption is possible only once." unless can_redeem_oath?

    update!(oathbroken_at: nil, oath_redeemed_at: Time.current)
    note_oath!("#{short_name} is redeemed: Oathsworn returns, and they keep one talent from their time oathbroken.", by: by)
  end

  private
    def note_oath!(text, by:)
      return unless campaign

      Roll.note!(campaign: campaign, by: by, character: self, text: text)
      campaign.broadcast_table_refresh
    end
end
