# The story roll form's fields. story_roll_args are Roll.story! arguments, for
# a scene that opens with one: only your own seated characters can be named
# (anyone else's gets a 404). story_roll_options are the odds, thorns and
# question alone, for a roll call.
module StoryRollParams
  private
    def story_roll_args
      character = Current.identity.characters.where(campaign: Current.campaign).played.active.find(params[:character_id]) if params[:character_id].present?

      { character: character, spend_spark: params[:spark].to_i, **story_roll_options }
    end

    def story_roll_options
      { question: params[:question], odds: (params[:odds].presence || 2).to_i, thorns: params[:thorns].to_i }
    end
end
