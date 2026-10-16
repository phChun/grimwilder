# Stands in for Random: returns the given faces in order, whatever the die.
# Action rolls take their d6s first, then their thorns.
FixedDice = Struct.new(:faces) do
  def rand(_range) = faces.shift
end
