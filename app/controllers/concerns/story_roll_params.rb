# The story roll form's fields, as Roll.story! arguments. Used by story rolls
# and by a scene that opens with one. Only your own seated characters can be
# named (anyone else's gets a 404).
module StoryRollParams
  private
    def story_roll_args
      character = Current.identity.characters.where(campaign: Current.campaign).find(params[:character_id]) if params[:character_id].present?

      { character: character, question: params[:question], odds: (params[:odds].presence || 2).to_i,
        thorns: params[:thorns].to_i, spend_spark: params[:spark].to_i }
    end
end
