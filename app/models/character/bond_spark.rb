# Spark from a changed bond (pg. 13, 23): when a character changes their bond
# toward another PC at the table, that PC takes spark, up to the 2 they can
# hold. Setting a bond for the first time isn't a change.
module Character::BondSpark
  extend ActiveSupport::Concern

  included do
    after_update :give_spark_for_changed_bonds, if: -> { saved_change_to_bonds? && campaign && !campaign.done? }
  end

  private
    def give_spark_for_changed_bonds
      before = Array(bonds_before_last_save).index_by { _1["character_id"] }

      bonds.each do |bond|
        old = before[bond["character_id"]] if bond["character_id"]
        next unless old && old["bond"].present? && old["bond"] != bond["bond"] && bond["bond"].present?

        ally = campaign.characters.played.active.where.not(id: id).find_by(id: bond["character_id"]) or next
        took = ally.settle_spark(take: true)
        ally.save! if took
        Roll.note!(campaign: campaign, by: identity, character: self,
          text: "#{short_name}'s bond with #{ally.short_name} is now #{bond["bond"]}: #{ally.short_name} #{took ? "takes spark" : "already holds #{Grimwild::MAX_SPARK} spark"}.")
      end
    end
end
