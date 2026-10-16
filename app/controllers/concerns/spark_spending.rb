# Anyone at the table can record a group roll (a quarrel, a montage), but only
# a character's own player decides to spend that character's spark.
module SparkSpending
  private
    def spark_to_spend(character, amount)
      amount = amount.to_i
      raise ArgumentError, "Only #{character.name}'s player can spend their spark." if amount.positive? && !character.owned_by?(Current.identity)
      amount
    end
end
