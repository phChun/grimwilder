// Filling a background's wises (pg. 49), kept pure so it's tested in Node.
//
// Switching from one common background to another replaces the boxes that
// still hold the old one's wises, and fills empty boxes; anything the player
// wrote themselves stays. Matching ignores case and spacing.
export function refillWises(values, previousWises = [], nextWises = []) {
  const key = (word) => word.trim().toLowerCase().replace(/\s+/g, " ")
  const previous = new Set(previousWises.map(key))

  return values.map((value, i) => {
    const replaceable = !value.trim() || previous.has(key(value))
    return replaceable ? (nextWises[i] || "") : value
  })
}
