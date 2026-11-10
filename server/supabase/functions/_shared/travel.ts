// Where travelling disciples go (M6), as Claude reads it. The game owns the
// rules (game/sim/data/travel.gd: how long, which letters, which gifts); the
// ids here must match it, which the Deno contract test checks against
// game/tests/fixtures/letter_request.json and game/sim/data/travel.gd.

export const TRAVEL_PLACES = {
  eastern_sea: "the Eastern Sea, where fishermen sing to the waves",
  noodle_town: "Longtang, a little town famous for its hand-pulled noodles",
  singing_sands: "the Singing Sands, a desert whose dunes hum at dusk",
  snow_peaks: "the Snowy Peaks, where old hermits meditate in caves",
  capital_market: "the night market of the capital, loud and full of lanterns",
  bamboo_sea: "the Southern Bamboo Sea, green as far as the eye can see",
  cloud_temple: "a temple above the clouds, reached by ten thousand steps",
  frog_swamp: "the swamp next to the Iron Frog Sect, very much by accident",
} as const;
export type TravelPlace = keyof typeof TRAVEL_PLACES;
export const TRAVEL_PLACE_IDS = Object.keys(TRAVEL_PLACES) as [TravelPlace, ...TravelPlace[]];
