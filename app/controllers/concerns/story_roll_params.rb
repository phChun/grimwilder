# The story roll form's fields: story_roll_options are the odds, thorns and
# question, for a roll for no one in particular or a roll call.
module StoryRollParams
  private
    def story_roll_options
      { question: params[:question], odds: (params[:odds].presence || 2).to_i, thorns: params[:thorns].to_i }
    end
end
