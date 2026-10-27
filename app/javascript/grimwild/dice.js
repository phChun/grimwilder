// Grimwild dice rules (Community Edition Preview 6, pg. 10–18).
//
// Action/defense rolls: roll d6s equal to the stat (plus spark, assists,
// talents) and any thorns (d8s). The highest d6 sets the result. Each thorn
// showing 7 or 8 cuts the result one step. More than one 6 is a critical,
// which thorns can't cut.
//
// Pools: roll every die, drop those showing 1–3.

export const RESULTS = ["perfect", "messy", "grim", "disaster"]

export function rollDie(sides, random = Math.random) {
  return Math.floor(random() * sides) + 1
}

export function rollDice(count, sides, random = Math.random) {
  return Array.from({ length: count }, () => rollDie(sides, random))
}

export function baseResult(highest) {
  if (highest === 6) return "perfect"
  if (highest >= 4) return "messy"
  return "grim"
}

// Interpret already-rolled dice. Kept pure so it can be tested.
export function interpretRoll(dice, thorns = []) {
  if (dice.length === 0) throw new Error("An action roll needs at least 1d")

  const highest = Math.max(...dice)
  const sixes = dice.filter((d) => d === 6).length
  const critical = sixes > 1
  const cuts = thorns.filter((t) => t >= 7).length
  const base = baseResult(highest)

  if (critical) {
    return { result: "perfect", critical: true, highest, cuts, appliedCuts: 0, base }
  }

  // Disaster is only reachable as a cut grim; extra cuts past it do nothing.
  const index = Math.min(RESULTS.indexOf(base) + cuts, RESULTS.length - 1)
  return {
    result: RESULTS[index],
    critical: false,
    highest,
    cuts,
    appliedCuts: index - RESULTS.indexOf(base),
    base
  }
}

export function actionRoll(statDice, thornCount, random = Math.random) {
  const dice = rollDice(statDice, 6, random)
  const thorns = rollDice(thornCount, 8, random)
  return { dice, thorns, ...interpretRoll(dice, thorns) }
}

export function rollPool(size, random = Math.random) {
  const dice = rollDice(size, 6, random)
  const remaining = dice.filter((d) => d >= 4).length
  return { dice, dropped: size - remaining, remaining }
}
