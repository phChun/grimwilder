# AGENTS.md — Grimwilder

Guidance for AI coding agents (and humans) working in this repo. Read this before changing anything.

## What this is

**Grimwilder** is a *play toolkit* for the tabletop RPG **Grimwild: Community Edition** (CE Preview 5.2).
It is **not** a rules reference/SRD. Each tool should quote only as much rule text as a player needs at the table.

Current state:
- Done: site layout (header nav, footer), home page (`/`), action roller (`/roll`), passwordless accounts (email code + passkeys), campaigns with join links, campaign pools, crucibles, character sheets and the talent catalog, and the table log (server-rolled character rolls that spend and award spark, plus pool rolls, live on the campaign page).
- Next: see *Roadmap*.

Source rulebook: `GWCE P5.2 Pages.pdf` (in the Claude project "Grimwilder", not in the repo). Page numbers below refer to it.

## Stack

| Piece | Choice |
|---|---|
| Ruby / Rails | Ruby **4.0.6**, Rails **8.2.0.alpha** (`main` branch from GitHub) |
| Views | `.html.erb` compiled by **Herb** and routed through **ReActionView 0.6** (reactionview.dev) |
| JS | importmap-rails, Turbo, Stimulus, the `reactionview` client (pinned automatically by the gem) |
| CSS | Plain CSS served by Propshaft. No Tailwind, no Sass |
| DB / infra | SQLite, Solid Cache/Queue/Cable, Kamal (`config/deploy.yml` still has placeholder values) |
| Tests | Minitest (`bin/rails test`) plus Node's built-in test runner for pure JS |
| Auth | Passwordless: emailed codes + passkeys (`webauthn` gem); no `has_secure_password` / bcrypt |

## Commands

```sh
bin/dev                                   # run the app (ReActionView also starts the Herb dev server)
bin/rails test                            # Ruby tests
node --test test/javascript/dice.test.mjs # dice-rule tests (Node 22+, no npm install needed)
bin/rubocop                               # Ruby style
npx @herb-tools/linter@0.11.0 app/views   # template lint, including reactive-state validation
```

Run the Herb linter after every template change. Its `herb-state-valid-reads` rule catches state expressions the browser can't evaluate. Those still render on the server but quietly stop updating in the browser.

## File map

```
app/
  assets/fonts/             # self-hosted Spectral + IBM Plex woff2 (OFL, licenses alongside)
  assets/stylesheets/
    application.css        # @font-face, design tokens (dark only), base, the shell (header, live banner), layout
    components.css         # buttons, cards, dice, roll results, pool tracks, pips, steppers, and each screen
  controllers/
    pages_controller.rb    # home
    rolls_controller.rb    # /roll (no server logic; all client-side)
  helpers/application_helper.rb   # TOOLKIT_NAV: the nav items; ready: false shows "soon"
  javascript/
    grimwild/dice.js       # PURE rules module: no DOM. Pinned as "grimwild/dice"
    controllers/roller_controller.js  # Stimulus: rolls, draws the dice tray, writes state back
  views/
    layouts/application.html.erb
    pages/home.html.erb
    rolls/show.html.erb    # the anonymous /roll page: reactive template (herb:state)
config/initializers/reactionview.rb  # intercept_erb + slots on
test/javascript/dice.test.mjs
.herb.yml                  # framework: actionview, template_engine: herb
```

## ReActionView conventions (important)

ReActionView's reactive templates are **experimental (^0.6.0)**. The markup, payload and JS API may change between releases. Check https://reactionview.dev and https://herb-tools.dev/language/state when upgrading.

**Config** (`config/initializers/reactionview.rb`): `intercept_erb = true`, `slots = true`, `debug_mode` in development.

**Template directives**: put them at the top of the template, each on one line, with no trim markers:
```erb
<%# herb:slots client %>
<%# herb:state (stat: 2, thorns: 0, mode: "action", outcome: "", critical: false) %>
```
- State defaults can be Boolean, Integer, String, Symbol or nil. **Float, Array and Hash are rejected.**
- `herb:slots client` means the browser evaluates everything and never asks the server. Use `server` only when a read needs Ruby or the DB. The controller then reads values with `herb_state(name, default)`.

**Actions** (HTML attributes):
- `data-herb-set="name=value"` (or `"change->name=value"`; `$value` is the element's value)
- `data-herb-toggle` (Boolean), `data-herb-increment` / `data-herb-decrement` (Integer, step set by `data-herb-by`)
- `data-herb-reset`, and `data-herb-action="$refresh"` (re-render the server-computed parts)
- Timing: `data-herb-debounce="ms"`, `data-herb-throttle="ms"`

**Expressions the browser can evaluate**: a bare state; `!`/`not`; `==`/`!=` against a literal; `< > <= >=` on Integers; `||`; `case/when` with literal arms; `nil? positive? zero? one? empty? blank? present?`; `to_s`; `length`/`size` on Strings.
- **Not supported**: `count`, computed Ruby like `(!x).to_s` or `titleize`, and ternaries. Templates can't assign state.
- If you need a computed value, add another state and set it from an action or from Stimulus.
- Boolean attributes (`disabled`, `checked`, `selected`) are added or removed based on the expression: `disabled="<%= stat <= 1 %>"`.
- `aria-pressed` and other non-boolean attributes can't be computed. Use radio inputs bound with `checked=` instead (see the Action/Defense switch on the roll page).

**Stimulus ↔ state**:
```js
import { useState } from "reactionview"
connect() { useState(this) }          // attach to the states around this element
this.state.get("stat")                 // read
this.state.set({ outcome: "messy" })   // write (updates every template part that reads it)
// optional: <name>Changed(value) callbacks, this.state.on("name", fn)
```
Pattern used here: **the template owns the inputs and the result text; Stimulus owns randomness and any DOM the template doesn't render** (the dice tray).

**Known gotchas**
- **Don't use `stylesheet_link_tag :app` or `:all`.** Herb compiles `stylesheet_link_tag` into a static `<link>` built with `stylesheet_path`, so the shorthand becomes a lookup for `app.css` and fails. List each stylesheet by name in the layout. **Adding a new CSS file means adding a new `stylesheet_link_tag` line.**
- Other tag helpers may get the same static compilation. If a helper does something unusual with its arguments, check the compiled output (the error page shows it).
- **`link_to` with an interpolated attribute value that contains a space comes out broken**: `"aria-label": "Account: #{name}"` (or `aria: { label: … }`) renders as `aria-label="Account:" gwen=""`. Write that `<a>` by hand (see `layouts/_app_header`); the linter's "prefer link_to" info is wrong there. `button_to` isn't affected.
- **Keep `locals:` defaults `nil`.** Herb prints non-nil defaults from a `<%# locals: (…) %>` line into the output (`size: 44, kind: "d6"` puts "d644" before the markup). Default to `nil` and fill in below (`<% size ||= 44 %>`); `test/helpers/shared_components_test.rb` checks the shared partials print nothing extra.
- Avoid `<%#=` commented-out output tags; the linter flags them.

## Grimwild glossary (domain definitions)

**Core roll**
- **Stats**: four, each 1–3 to start (every stat starts at 1, plus 4 more points to assign). **Brawn** (power, menace, toughness), **Agility** (precision, athleticism, reflexes), **Wits** (smarts, trickery, reading situations), **Presence** (influence, willpower, reading people). Brawn and Agility are physical; Wits and Presence are mental. (pg. 22)
- **Action roll**: roll d6s equal to the stat, plus extra dice from spark, assists and talents. **The highest d6 is the result.** (pg. 10, 17)
  - **Perfect** (6): success, and you avoid trouble.
  - **Messy** (4–5): success, with an impact move.
  - **Grim** (1–3): failure, with an impact move.
  - **Disaster** (a grim that gets cut): failure, with a worse impact move. The player takes spark.
- **Defense roll**: made to avoid danger that *didn't* come from the PC's own action. Perfect = avoid the impact move, messy = reduce it, grim = take it in full, disaster = take a worse one, then take spark. (pg. 15)
- **Thorns (t)**: d8s added for difficulty factors. A 7 or 8 is a **cut**, which lowers the result one step (perfect → messy → grim → disaster). Each cut counts separately. Typical play uses 0–2 thorns; there's no cap. (pg. 11)
- **Critical**: a perfect with **more than one 6**. Thorns can't cut it. Pick one: **Greater effect** (drop 1d from the task pool before rolling it), **Secondary effect** (also gain the effects of another related perfect), **Setup** (a riskless assist on a follow-up roll). If nothing fits, take spark. (pg. 10)
- **Story roll**: tests luck or how true a detail is, from good to bad. Usually 2d. (pg. 16)
- **Montage roll**: summarizes a stretch of activity. (pg. 16)
- **Quarrel**: PC against PC. Each player rolls 2d and the higher die wins. (pg. 23)
- **Vantage**: what's plausible for this character right now, based on their sheet, reasonable inferences and the scene. The vantage scale: **Certain** (no roll needed), **Reasonable** (+0–1t), **Doubtful** (+2t or more), **Impossible** (no roll allowed). (pg. 12–13, 17)
- **Impact move**: a GM action that brings trouble; usually triggered by messy, grim or disaster results. (pg. 100)

**Meta-currencies**
- **Spark**: spend it before any roll for +1d per spark. A character holds at most 2, and it carries over between sessions. Gained from tangles, rolling a disaster, resolving a story arc, quarrels, or an ally changing their bond with you. (pg. 12)
- **Thread**: 2 per session. Spend it to add story details that go beyond set dressing. (pg. 25)
- **Tangle**: a complication the player introduces from their own vantage; they take spark for it. (pg. 25)
- **Suspense**: the GM's currency, used for things like making extra moves or dropping 1d from a pool. The GM gains it by skipping a prompted impact move or making suspense moves, and at the start of each session after the first; spending it prompts an impact move. Some talents give it away (Challenge, Provoke, Wordplay). (pg. 96)

**Play structure**
- **Session**: one sitting. Before every session after the first, each player takes spark, resets thread and per-session talents, and shares their PC's best moment from last time; the GM takes suspense and recaps ("Previously on…"). After each session, everyone takes 1 XP, or 2 for a standout session (about 1 in 4). (pg. 31)
- **Scene**: one stretch of action. It opens in the middle of things (with a story roll if the setup is unclear) and closes with a montage once it has served its purpose. Short-term conditions can wear off after a scene, and some talents work "for a scene" or reset each scene. (pg. 29, 95)
- **Rest**: a significant stretch of time; clears all marks and harm. (pg. 30)
- **Downtime**: PCs fully heal, including relevant conditions, and reset per-session talents; the GM rolls faction (campaign) pools. (pg. 30)

**Damage** (pg. 27–30)
- **Mark**: a light hit to one stat. +1t on the next roll with that stat, then the mark clears. A second mark on an already-marked stat becomes harm instead.
- **Harm**: **Bloodied** (physical; +1t to Brawn and Agility), **Rattled** (mental; +1t to Wits and Presence), **Desperate** (+1t to everything; comes from a second bloodied or rattled). Harm while desperate leaves you **dropped**: out of the scene, and you make a story roll to see how bad it is.
- **Vex**: a fear response: fight, flight, freeze or freakout.
- **Conditions**: urgent, short-term, long-term or permanent. Often a timer pool, e.g. `4d poisoned`. +1t when relevant.
- A significant rest clears all marks and harm.

**Diminishing pools** (pg. 18–19)
- A pool is a set of d6s that tracks progress. Roll it when triggered and **drop every die that shows 1–3**. When it reaches **0d**, the event happens.
- Notation: size first, in italics, e.g. *4d* Barroom Brawl. Usual sizes are 2d (short), 4d (medium), 8d (long). On average, 2d clears in about 2.7 rolls, 4d in about 3.5 and 8d in about 4.4. Pools bigger than 8d barely change that.
- Types:
  - **Task**: effort toward a goal, or defeating an enemy.
  - **Pressure**: an approaching threat.
  - **Timer**: background events.
  - **Resource**: a supply; you must be able to roll it to use it.
  - **Power**: rolled *as* an action roll. Its highest die is the result, then 1–3s drop as usual. Spark dice are tracked separately.
  - **Linked**: phases; e.g. 4d+4d works like a 51d pool, about 7 rolls.
  - **Campaign**: long-term, rolled during downtime.
- If a task pool drops nothing, you can **push** (take a mark and drop 1d anyway) or **pivot** (take a secondary effect instead).
- *Tick pools* (optional rule): drop exactly 1d each time and are never rolled. (pg. 177)

**Other terms**
- **Crucible**: a 6×6 random table. Roll 2d6 for the row and column; many tools say "roll 2 on each table and smash them together." Examples: character, NPC, heritage, arcana, GM, wild surge, building (pg. 135), exploration, settlement and site (pg. 138).
- **Bonds**: an intensity plus a nature describing how one PC sees another, e.g. "tense rivalry." (pg. 22)
- **Traits / Desires**: pick 2 that fit the character and 1 that doesn't. (pg. 20)
- **Wises**: areas of knowledge or expertise that expand vantage. (pg. 20)
- **Story arcs**: a group arc plus a character arc. Resolving one gives spark. (pg. 26)
- **Paths**: the character classes, e.g. Fighter, Rogue, Wizard, Druid. Each has a core talent and path talents.
- **Enemy tiers**: tough (standard) → elite → boss; mooks are minor foes. Higher tiers get larger task pools to defeat. (pg. 109)

## Dice implementation

The rules live in two places, and both are kept **pure** (no DOM, no database) with the randomness passed in so tests are deterministic:
- `app/javascript/grimwild/dice.js` for the anonymous `/roll` page, which never touches the server.
- `app/models/grimwild/dice.rb` (`Grimwild::Dice.roll` / `.interpret`) for rolls the server makes. Character rolls are server-rolled so the shared log can be trusted; `Pool#roll!` rolls its own d6s.
- Both are tested against the same cases in `test/dice_examples.json`. **Change a rule in both files and add the case to the JSON.**

In JavaScript:
- `interpretRoll(dice, thorns)` returns `{ result, critical, highest, cuts, appliedCuts, base }`.
- Extra cuts past disaster have no effect (`appliedCuts` ≤ `cuts`). A critical ignores every cut.
- `rollPool(size)` returns `{ dice, dropped, remaining }`.
- Where you can, use the worked examples in the book as test cases (e.g. pg. 122: `[2,6]` vs a 7 thorn gives messy; `[3,4,2]` vs thorns `7,8` gives disaster).

## Table rolls & the log

- **Roll** is one entry in a campaign's log: an `action` or `defense` roll from a character sheet, a `story` roll, a `quarrel`, a `montage`, or a `pool` roll, drop-first or push.
- **Power pools** (pg. 19): `Pool#roll!(as_action: true, thorns:, character:, spend_spark:)` rolls the pool as an action roll in place of a stat. The highest die is the `outcome`, then 1–3s drop. Spark dice count toward the result but never drop or join the pool, and they're stored after the pool's own dice in the Roll's `dice` (the last `spark_spent` of them). A disaster gives the character spark. A plain roll is the use that isn't risky: it works, and dice still drop. Names are copied in when the roll is made, so the log survives renames and deletes. Rolls on hidden pools are `gm_only`.
- `Character#roll!(stat, by:, mode:, spend_spark:, help:, assists:, thorns:)` (in `Character::Rolling`) does everything in one transaction: it spends spark (+1d each), rolls 1d for each assisting character (pg. 13; stored in `assists` and counted via `Roll#all_dice`, so an assist can set the result or make a critical), adds damage thorns, clears the stat's mark, gives spark on a disaster (capped at `Grimwild::MAX_SPARK`), and records the Roll. Unseated characters' rolls are kept but have no campaign, so they aren't logged.
- Rolls happen on the sheet. Each stat card's Roll button is a `<details class="stat-roll" name="stat-roll">` (one open at a time; the open card spans the stat grid's row) holding the setup form (`characters/_roll_form`). It posts to `characters/:id/rolls#create`, which redirects back to the sheet; the morph refresh closes the setup and shows the result in the "Last roll" card (`characters/_last_roll`, the character's newest action/defense roll). There are no separate setup or result pages any more.
- A critical where no effect fits gives spark (`Character#take_spark_for_critical!`, from a button on the sheet's Last roll card): owner only, once, on the character's latest roll, below 2 spark. It sets `spark_gained` on the Roll, which then reads "Critical: nothing fit…" instead of "Disaster…".
- Updating a Roll replaces its log entry live, the same way new rolls are prepended.
- **Story rolls** (`Roll.story!`, in `Roll::Story`; pg. 16) come from the campaign page: 1d/2d/3d for bad/even/good odds, rare thorns, and a `question`. They're made for one of your own seated characters (spark can go in, and a disaster gives spark) or for no one. `stat_dice` holds the odds.
- **Quarrels** (`Roll.quarrel!`, in `Roll::Quarrel`; pg. 23) have their own page. Each side rolls 2d plus any spark, and each assist rolls its own 1d (pg. 13). The highest die wins, and a tie has no `winner`. Everyone involved takes spark. Sides go in the `sides` JSON and the stakes in `question`. Any member can record a quarrel, but only a character's own player can spend its spark (the `SparkSpending` controller concern).
- **Montages** (`Roll.montage!`, in `Roll::Montage`; pg. 16) have their own page too. Each seated character taking part rolls 2d plus any spark, with no thorns, since the book gives montages none. The best single result is the scene's `outcome`, and each character's own result goes in `sides`, so the table can see what to zoom in on. The scene goes in `question`.
- `Character#settle_spark(spent:, take:)` is the one place spark is spent before a roll and taken after it, capped at 2. It doesn't save.
- Live updates: `Roll` prepends `rolls/_roll` to `#roll_log` over `[campaign, :rolls]`, or over `[campaign, :gm_rolls]` for GM-only rolls. The GM table renders `rolls/_log` (locals `campaign:`, `membership:`, `rolls:`: the list only, no heading), which subscribes to `Roll.streams_for(campaign, membership)` itself; load the entries with `campaign.rolls.table_log(membership)`. `rolls/_roll` renders in a job, so it must not use `Current`.
- In tests, `assert_no_turbo_stream_broadcasts` counts every broadcast so far in the test, not just the ones inside its block. `FixedDice` (test/test_helpers) stands in for `Random`.

## Table chat

- **`Message`** (`messages`): `campaign`, `identity`, optional `character` (speaking in character), `name` (copied in), `body` (≤ 500 characters). It's separate from the roll log on purpose, so talk never buries rolls; log notes (`Roll.note!`) still exist for one-line game events.
- Anyone at the table posts (`POST /campaigns/:id/messages`, `Campaigns::MessagesController`), as themselves or one of their own characters seated there; the model validates that too.
- Live: `after_create_commit` broadcasts (synchronously, for chat latency) an append of `messages/_message` to `#chat_messages` over `[campaign, :chat]`. The sender sees their line the same way, so a Turbo submit gets `204`, and `chat_form_controller.js` clears the box (Enter sends, Shift+Enter is a new line). `messages/_message` renders outside requests: no `Current`.
- `messages/_chat` (locals `campaign:`, `messages:`, `speakers:`, `speaker:`) is on the GM table (`#chat`) and in the character view's rail. `Message.chat_for(campaign)` gives the newest 40, oldest first. Newest is at the bottom; a `column-reverse` scroller keeps it pinned without JS.
- Times are `<time datetime>` shown in the viewer's zone by `local_time_controller.js` (re-run after a morph); the server fallback is UTC.

## The GM table (campaigns/tables#show)

Night-table phase 3. **`/campaigns/:id/table`** (`Campaigns::TablesController`, `require_gm`) is the GM table, built from `CampaignTable#load_table` like the old page: a scene bar ("Session 8 · live 1h 12m · Scene 2 of 2", the scene title, Story roll / Montage / Quarrel, then Cut to new scene, End session, and a "Rest or downtime" fold-out) beside a suspense panel (− diamonds +, "players can see it"); party cards (`harm_line`, spark and thread, talent uses and talent pools; a member without a character gets a dashed card); pools as cards (`campaigns/pools/_card`); the story roll fold; the crucible; and a rail with the log, a note box and chat.
- Pool cards: the dice count, a track (`shared/_pool_track`) or the last roll's dice when rolled this scene (`pool_card_shows_last_roll?`, "6d → 4d · 2 minutes ago"), a ⋯ menu (drop-first, push, reset, hide, delete, the power-pool action roll) and "Roll Nd". Hidden pools are dashed purple with an eye-off icon, a purple Roll and **Reveal** (PATCH `hidden: false`). An empty resource pool dims, says "All gone." and offers **Restock to Nd** (the reset).
- "Cut to new scene" opens the end-scene form with `then=new_scene`; ending it then redirects to the new-scene form.
- Redirects: campaign controllers send people back with `back_to_table` (`CampaignScoped#table_path_for_viewer`): the GM to the GM table, a player to `campaign_path`. `/pools` and `campaign_play_path` follow the same rule. A pool that fails to save renders `campaigns/tables/show`.
- Shared with the campaign page: `details_memory_controller.js` remembers each `<details>` section's open/closed state per browser in localStorage (keyed by campaign and section), and restores it after a Turbo morph, because a pool refresh re-renders the page with the server's defaults. The new-pool form (`campaigns/pools/_form`) keeps its own herb:state. **Crucibles** load in a `turbo_frame_tag "crucible"` from `crucible_path(key, embed: 1)` (`crucibles/_roller`, `crucible_controller.js`); `crucible_picker_controller.js` swaps the frame's `src` and keeps three "Recent" chips; the section is `data-turbo-permanent`, so morphs don't wipe a roll.
- Turbo drops a redirect's `#fragment` after a form post, so pool actions land at the top of the page rather than on the card.

## The campaign page (campaigns#show)

Night-table phase 4. The series overview, for the GM and players alike (`CampaignsController#show`: `load_table` plus `load_overview`):
- **Hero**: "Campaign · You're the GM" / "Playing Tibbs", the name, the one-line `pitch` in Spectral italic, and four facts: `party_is` (two concepts, JSON), `party_never`, `group_arc`, `setting` (columns on `campaigns`, set by the GM in settings; a GM with none gets a prompt). The action card: the GM's "Open the GM table", "Copy invite link" (`campaigns/_copy_join_button`) and "Reset link"; a player's "Open my character" (`Membership#seated_character`) or "Make your character".
- **The party**: a card per active character (monogram, short name, path and level, player, spark pips, four stat tiles with a marked stat red and ✕, the harm line); a member with no active character gets a dashed "joined · still making a character" card. Characters have a **`status`** (`active`, `fallen`, `retired`; the owner sets it on the edit form), and fallen and retired ones are one line under the grid. `seated_character` only counts active ones.
- **Previously on…**: the last ended session (date, scenes and roll counts, recap, each scene with `scene_outcome`: how it closed, a quarrel, a pool running out, or its opening story roll) and its best moment as a pull quote. Moments about a session are written in the next one (`PlaySession#moments_about`). Then the two before it and "All N sessions". Sessions have no names, so they're headed "Session N".
- **Side column**: "Hanging over them": the GM sees visible shared pools as tracks plus "N hidden pools, only you see it"; players get the pool rows (`campaigns/pools/_pool`, with drop-first, push and the power-pool action roll) and the story roll fold. Then "At the table" (members with their character, "GM" or "making one", and Campaign settings), "Kept crucibles" (`kept_crucibles_controller.js` reads the per-crucible lists `crucible_controller.js` keeps in this browser's localStorage; hidden when there are none), and for players the table rail (log with the note box, chat, read-only suspense, Montage and Quarrel links).
- **Settings** are `campaigns#edit` (`edit_campaign_path`): the GM's pitch form (name, pitch, the party is/never, group arc with the book's arcs as suggestions, setting), the invite link, members (remove, or leave for a player) and delete. Removing someone returns there.
- Tabs: "Characters" (GM) and "Party" (player) go to `#party`.

## Sessions & scenes

Built in steps from a design brief: (1) sessions, (2) scenes, (3) talent uses, (4) history and moments, (5) rest and downtime.

- **`PlaySession`** (table `play_sessions`; `Session` is sign-in). `number` per campaign, `started_at`/`ended_at`, `recap` ("Previously on…", not on session 1), `notes` (from the end form), `standout`. A campaign has at most one open session (validation plus a partial unique index); `Campaign#current_session`.
- **Attendance** is the `play_session_characters` join table (`PlaySession#characters`, `Character#play_sessions`). Only characters marked present get a session's resets and XP.
- **`PlaySession.start!(campaign, characters:, recap:, by:)`** runs `Character#start_session!` for each present character: thread resets to `Character#session_thread` and they take spark, but not before session 1. The campaign takes 1 suspense (also not before session 1). **`PlaySession#end!(by:, standout:, notes:)`** gives each present character `gain_xp!`, twice if standout, and returns those who levelled up.
- **Markers**: boundaries post a `marker` kind of `Roll` ("Session 4 begins", recap in `question`, level-ups in `sides` with links to choose a talent). They broadcast like rolls, and `Campaign#broadcast_table_refresh` refreshes every table over `[campaign, :table]`.
- **Stamping**: every Roll gets `play_session` (and `scene`, while one is open) from the campaign when created. Older rolls have neither ("Before sessions").
- **`Scene`**: `number` per session, `title`, `notes`, optional `opening_roll` (a story roll) and `closing_roll` (a montage from the scene). One open scene per session; `Campaign#current_scene`, `PlaySession#current_scene`. **`Scene.start!(session, title:, by:, opening:)`** takes `Roll.story!` arguments for the opening (the `StoryRollParams` controller concern builds them from the story form). **`Scene#end!(by:, clear:, notes:, closing_roll:)`** clears the picked "clears after scene" conditions (`clear` is `"character_id:index"` strings; the end form ticks them all by default). `PlaySession#end!` ends an open scene first, with the same `clear:`.
- **Conditions** are `{ "name", "lasts" }`, where `lasts` is `"scene"` or nil (`Character::Damage::CONDITION_LASTS`); `conditions=` accepts plain strings too. `Character#scene_conditions` gives `[index, condition]` pairs.
- **Notes**: a `note` kind of Roll (`Roll.note!(campaign:, by:, text:, character:)`) is one short line in the log, with no dice. Anyone at the table can add one from under the log.
- Rolling a montage with `then=end_scene` returns to the end-scene form, which offers it as the closing roll.
- **Talent uses**: talents in `config/talents.yml` can list `uses:`. Each is a `Talent::Use` (`Talent#uses`) of one of three kinds: a count (`count`, shown as tick boxes), a talent pool (`pool`, `pool_kind`), or extra thread per session (`thread`). Each has a `per` of `session` or `scene`, and `growth` (`{ level => more }`; `count_at(level)`, `pool_at(level)`). `Talent::Use#id` is `"talent-key/use-key"`. `test/models/talent_use_test.rb` checks every entry is well formed.
- `Character::TalentUses`: `talent_uses` (JSON, spent counts by use id), `spend_use!`, `talent_thread` (raises `session_thread`, and so thread's cap), and talent pools. A talent pool is a `Pool` with `character_id`, `refresh` and `use_key`, in the character's campaign, named "Ash: Bulwark". `PlaySession.start!` resets every use and refills (or creates and resizes) every talent pool for each present character. `Scene#end!` does the same for the per-scene ones.
- On the sheet, the Talent uses panel shows tick boxes (PATCH `characters/:id/talent_uses`, for the owner and the campaign's GM). Ticking can post a note to the log ("Fen spends inspiration"); that choice is remembered per browser. Talent pools show as pool rows on the sheet (rolling them there returns to the sheet via `return_to=character`) and under the character on the table. The table's main pool list is `Pool.shared` only.
- **Best moments**: `PlaySession::Moment` (`play_session_moments`): one per character per session, about the session before, written at the start of this one. Players write their own characters' and the GM anyone's (`Moment.writable_by?`). The table prompts you for your own present characters until each has one (`PlaySession#characters_needing_moments`, filtered to characters you own; the GM writes other people's from the session page). The prompt is a `<details>` you can close, which details-memory remembers.
- **History**: `campaigns/:id/play_sessions` lists sessions (date, recap snippet, scenes, attendance, XP and level-ups from the end marker via `PlaySession#level_ups`) and folds the "Before sessions" log underneath. `campaigns/:id/play_sessions/:id` shows the recap, notes, moments, attendance and each scene (opening and closing results, notes, its rolls oldest first), then anything outside scenes. GM-only rolls stay GM-only. The GM can edit a session's recap and notes and a scene's title and notes there. The session bar links to the history.
- **Rest and downtime** (`Campaign::Breaks`; pg. 30), from the GM's "Between scenes" fold-out in the session bar. Both apply to `Campaign#resting_characters`: those at the current session, or everyone seated between sessions. `Campaign#rest!` clears marks and harm (`Character#rest`). `Campaign#downtime!(clear:)` also clears the conditions the GM leaves ticked on its form (all are ticked, so untick permanent ones), resets per-session talent uses and refills talent pools, and rolls every shared `campaign` pool (`Campaign#downtime_pools`). Each posts one marker. Campaign-level markers come from `Campaign#post_marker!`; `PlaySession#post_marker!` passes itself along.
- Talent effects deliberately not modelled: Mischief Maker's rising story-roll thorns, Augury's omens, Magnum Opus's touchstones, Herbalism's herb names and one-time major potion, Oathsworn's Affirmation, Awakened Mind's instability thorns, Vassal refilling at 0d, and the pools Echo, Soothsayer and Awaken create when used (only the use is counted). Quarry tracks one Quarry pool per session even though two quarries can be designated. Flesh Wounds and similar are just conditions marked "clears after scene".
- **Suspense** is `campaigns.suspense`: the GM's +/- counter in the session bar (`require_gm` on changes). Everyone at the table sees it (night-table brief): `campaigns/_suspense_meter` shows it read-only in the sheet's rail, and a change replaces it live over `[campaign, :live]`. It's never logged.
- **Session bar**: under the campaign name in the GM table's header. It shows "Session 4 · started 20 min ago" or "Between sessions"; the GM's actions sit beside it, folded away on phones.
- All boundary actions are GM-only (`require_gm`), and their reset logic lives in the models.

## Accounts & campaigns (passwordless)

Modelled on Fizzy (github.com/basecamp/fizzy): no passwords, ever.

- **Identity**: a person, keyed by email (`name` = display name). **Session**: one row per sign-in, found via the signed, http-only `session_token` cookie. `Current.session/identity/campaign/membership` hold request state.
- **MagicLink**: a 6-character base32 code emailed by `MagicLinkMailer` that expires in 15 minutes and is single-use. It is keyed by *email address*, not Identity, so asking for a code never creates an account and never reveals whether one exists; the Identity is found or created when the code is redeemed. The code only works in the browser holding the signed `pending_authentication` cookie. In development the code is also shown on the page. `MagicLink.cleanup` runs hourly (config/recurring.yml).
- **Passkey**: a WebAuthn credential (gem `webauthn` ~> 3.4). Discoverable credentials (`resident_key: required`, `user_verification: required`) allow usernameless sign-in. Challenges are kept in the Rails session between the `.../challenge` POST and the verify POST. `passkey_controller.js` does the base64url conversion by hand and needs no browser JSON helpers. `APP_ORIGIN` must equal the site's origin in production.
- **Campaign** is the tenant. **Membership** (role `gm` | `player`) joins an Identity to a Campaign. Anyone signed in can start a campaign and becomes its GM. Players join via `/join/:code`, a reusable link the GM can reset. A campaign always keeps at least one GM.
- **Tenancy = shared database + `campaign_id`** (decided 2026-10-15; we do *not* use activerecord-tenanted). People belong to many campaigns, and "my campaigns/characters" needs queries across all of them. Campaign-owned controllers `include CampaignScoped`, which loads the campaign *through* `Current.identity.memberships` (non-members get a 404). Use `require_gm` for GM-only actions. New campaign-owned models get `belongs_to :campaign` and are always queried through `Current.campaign`.
- The play tools stay public. Controllers opt in with `require_authentication`; `require_unauthenticated_access` is for sign-in pages.
- Tests: `sign_in_as(identity)` in integration tests goes through the real code flow. Passkey tests use `WebAuthn::FakeClient.new("http://www.example.com")`.

## Pools (built 2026-10-15)

- `Pool` belongs to a campaign: `kind` (task/pressure/timer/resource/power/campaign), `starting_size` 1–20, `size` (0 = it happens), `hidden` (GM only), and the last roll (`last_dice` json, `last_dropped`, `last_action` rolled | rolled_after_drop | pushed, `last_rolled_by`).
- Rolls happen **on the server** (`Pool#roll!`), so the table shares one truth. `Pool#roll!` mirrors `rollPool` in dice.js; tests pass a fake `random:`.
- Routes: `/campaigns/:id/pools` plus nested `roll`, `push` and `reset` resources. `/pools` redirects to the latest campaign's pools.
- Permissions: members roll and push the pools they can see; the GM adds, resets, hides and deletes (`require_gm`). Players get a 404 for hidden pools.
- Live updates: `broadcasts_refreshes_to [campaign, :pools]` + `turbo_stream_from` + morph refreshes. Each viewer refetches with their own permissions, so hidden pools never leak.
- ReActionView: per-row `herb:state (drop_first: false)` under `herb:key pool.id`, and `new_size` bound to the size presets and the number input.
- Linter gotcha: inside a keyed loop, Herb treats the loop variable as row state, so `pool.size != pool.starting_size` fails `herb-state-valid-reads`. Move comparisons like that into model methods (`Pool#resettable?`).
- Not yet: linked pools (phases), tick pools, power-pool action results.

## Crucibles (built 2026-10-15)

- Data lives in `config/crucibles.yml`, not the DB. `Crucible` is a plain Ruby class (YAML is reloaded every request outside production), and each table is a `Crucible::Table` Data object.
- There are 13 crucibles and 32 tables: GM, settlements, sites, dangers, curiosities, barriers, factions, buildings, heritage, expanded wises (column headers), distinctive features, arcana (5 themes), and wild surge.
- The YAML was extracted from the PDF's text layer. Multi-word cells ("fortune teller", "over the hill", "laws of the land") were split by hand. When adding tables, check the cell boundaries against the PDF; `test/models/crucible_test.rb` enforces 6x6 tables with no blank cells.
- Rolling is client-side and public (`crucible_controller.js`, using `rollDie` from dice.js). Each 2d6 roll highlights both readings, row/column and switched (pg. 6). Tapping a chip chooses a word, "Keep" saves the combination to localStorage per crucible, and `herb:state show_tables` toggles the grids.
- Not yet: the path-specific crucibles (spell, patron, vassal, swashbuckler names, herbalism, eldritch mutations) and the seasons/months tables (their columns came out garbled in the text layer).

## Characters (built 2026-10-15)

- `Character` belongs to an identity (its owner) and can optionally be seated in one of that owner's campaigns. Owners edit; members of the seated campaign can read the sheet; everyone else gets a 404 (`Character.visible_to`).
- Book reference lists (paths with core talents, the 18 backgrounds with their wises, traits, desires, weapon styles, bond words, arcs) live in `config/grimwild.yml` and are read through the `Grimwild` module.
- Stats are 1–3 each and must total 8 on create. Detail lists (backgrounds, traits, features, bonds…) are json columns; the model setters clean and cap them, and accept Rails' `{"0"=>…}` nested form hashes.
- `Character::Damage`: marks per stat, bloodied/rattled/desperate, conditions, and `damage_thorns(stat)`. `roll!(stat)` clears that stat's mark. `Character::Advancement`: XP fills level+1 boxes, then levels up (max 7).
- **Roll from the sheet:** see *Table rolls & the log*. The setup folds open on the stat card and the result shows in the sheet's Last roll card.
- **The character view** (`characters#show`, `.fluid.play-view`; night-table phase 2): an identity band (monogram from `Character#short_name`, spark/thread pips, XP, and an owner-only "Adjust" fold-out with spark, thread, +1 XP and Edit sheet), four stat cards, then Last roll beside Harm, then "Who … is" beside Talents & arcs, then talent uses and notes. A seated character gets the table rail (`.table-rail`: "The table" with read-only suspense, then the live Roll log and Chat, remembered by `details-memory` as `sheet-log` / `sheet-chat`), which drops below the sheet on a phone. An unseated character gets `.play-view--solo` and no rail. Other viewers see the same page with every control hidden.
- **Stat cards**: the owner's Roll button is a `<details class="stat-roll">` (`characters/_roll_form`); the open card spans two columns with an ember ring. Its steppers show totals: `dice` (the stat's own plus extras, min = the stat) and `total_thorns` (damage thorns plus situational, min = damage). `Characters::RollsController` takes the difference as `help` and situational `thorns`, only after checking the stat name, because `Character#stat` is a `public_send`. `help`/`thorns` still work as before. Roll and Defense are two submit buttons (`name="mode"`); `stat_roll_controller.js` keeps the "Roll 3d + 1t" label current with spark and assists.
- **Harm card**: Bloodied, Rattled and Desperate toggles (Desperate isn't in the mockup but is a rule), the four stat marks (moved off the stat cards), conditions, and adding one. A condition written as a pool (`"4d poisoned"`, `Character::Damage::CONDITION_POOL`) shows its size and a Roll button: `Character#roll_condition!` (POST `characters/:id/conditions/:index/roll`) rolls it like a pool, drops 1–3s, renames it (`"2d poisoned"`), and logs a `pool` kind of Roll with no `pool_id`. At 0d it stays until cleared.
- **Who changed harm**: callers set `Character#changed_by` (the sheet, rolls, condition changes, rest, downtime, scene end), and a `before_save` records `harm_change` ("cleared Bloodied and the Agility mark"), `harm_changed_by` and `harm_changed_at`. The Harm card shows "GM cleared Bloodied · 3 minutes ago" when that wasn't the owner (`harm_changed_by_someone_else?`). Today only the owner edits a sheet, so other people's changes come from rest, downtime and scene ends.
- **Last roll** (`characters/_last_roll`): grim-red for grim and disaster, built on `shared/_roll_result` with the result text as `detail:`. Its only follow-up is "Nothing fits: take spark" on a critical: spark and assists go in before a roll (pg. 12–13), so there's no reroll or "ask for help".
- Quick changes on the sheet (marks, harm, spark, thread) are `button_to` PATCHes with `quick: 1`, with morph refreshes on the page.
- Herb linter false positive: a hash key with a state's name (`@preset[:thorns]` on the roll page) counts as reading the state. Rename the key (`:damage_thorns`).
- Not yet: a talent catalog (talents are free text plus the path's core talent), path-specific sheet parts, spending spark straight into a roll, and auto-taking spark on a disaster.

## Talents (built 2026-10-15)

- The catalog is `config/talents.yml`: 17 paths, each with its core talent plus 7 path talents, and 11 background/heritage talents (pg. 89), for 147 in all. `Talent` and `Talent::Group` are Data classes loaded from the YAML; keys are slugged names (`according-to-plan`).
- It was extracted from the PDF's text layer by a script: talents start at `NAME:` lines, and the book's sidebar tips go in `note`. Several core talents were cleaned up by hand (Artificer, Berserker, Druid, Monk, Psion, Swashbuckler, Warlock, Witch). The PDF's hyphenation leaves U+0002 control characters, which a test now guards against.
- "[Prohibited: Path]" in a talent's text blocks that path (`Talent#prohibited_for?`, validated on `Character`).
- Characters store chosen talents in `talent_keys` (json). The core talent always comes from the path. Expected count = level (one at creation, plus one per level); `talents_to_choose` drives the reminder, and levelling up redirects to the picker.
- `/talents` is the public catalog, filtered client-side (`talent_filter_controller.js`). `/characters/:id/talents/new` is the same catalog with Take buttons, the character's own path first.
- The free-text `talents` column is now "Talent notes", for choices talents ask for (skills, spells, tricks) or homebrew.
- Not yet: the Monk martial arts style, Rogue thieves' guild, and other optional path builders; legacy talents (pg. 190–191).

## Design system (the night-table direction)

The UI rethink (brief "Grimwilder: night-table UI", 2026-10-20; mockups in the local, git-ignored `docs/design/ui-rethink/`) is being built in five phases: (1) tokens and shell, (2) character view, (3) GM table, (4) campaign page, (5) chat. Phases 1 (shell), 2 (character view), 3 (GM table) and 4 (campaign page) are done; screens not yet rebuilt still use their older class names in the new palette.

- **Dark only.** Every color, font and radius is a custom property in `:root` in `application.css`; templates and components use only the variables. The older names (`--paper`, `--ink`, `--moss`, `--font-body`…) are aliases kept until each screen is rebuilt. Don't use them in new work.
- Fonts are self-hosted through Propshaft (`app/assets/fonts`, `@font-face` in `application.css`): **Spectral** (500, 700, italic 500) for names, headings and in-character speech (`--font-display`); **IBM Plex Sans** (400, 500, 600) for UI (`--font-ui`); **IBM Plex Mono** (500, 600) for dice and counts (`--font-dice`). No Google Fonts.
- Body text is 15px, line-height 1.5. Every button and input is at least `--tap` (44px) tall; icon-only buttons have an `aria-label`. Icons are inline stroke SVGs from `icon(:name)` (`IconsHelper`), never emoji or glyphs.
- Results: `--perfect`, `--messy`, `--grim` (plus `--grim-ring`/`--grim-bg`/`--grim-line` for cards), and `--disaster`, which is ours: the palette has no disaster color. Always show the word (Perfect, Messy, Grim, Disaster, Critical) next to the color. Meta-currencies: `--spark` amber circles, `--thread` blue diamonds, `--suspense` purple diamonds.
- Primary actions are `--ember`. One `.button--primary` per area; `.button` is the outline secondary, `.button--ghost` text only. Buttons and cards are CSS classes (`.button…`, `.card`/`.card--dashed`) because `button_to`, `link_to` and submits all need them; `shared/_card` wraps a block when that's tidier.
- Page layout: `.fluid` > `.fluid__main` (flex 999 1 640px) + `.fluid__rail` (flex 1 1 340px, max 420px), so the rail drops under the content on a phone. Keep a 16px gutter and no horizontal scrolling at 390px.
- BEM-style class names. Accessibility: a skip link, `:focus-visible` outlines (`--focus`), `aria-live` on changing results, `prefers-reduced-motion` respected.

**Shared partials** (`app/views/shared`), which every rebuilt screen is assembled from:
- `_die` (`value:, kind:, state: nil|:highest|:dropped, size: 28|32|44`): a d6 gets its own tier class (`die--perfect/messy/grim`), so the highest die fills with *its* result's color (a 5 cut to grim is still messy-ochre); a d8 is a ring, red when it cuts. Classes `die--top`/`die--dropped`/`die--cut` are shared with `roller_controller.js`. `RollsHelper#roll_dice_tags` renders every roll's dice through it.
- `_roll_result` (`roll:, size:, heading:`): dice, the word (`roll_result_word`) and the reason line (`roll_reason`: "Messy, cut to grim by a thorn"). No `Current`, so it renders in broadcasts.
- `_pool_track` (segments = the current phase's `starting_size`; purple when hidden), `_pips` (`kind:, value:, max:`, always with an `aria-label` like "1 of 2 spark"), `_segmented` and `_stepper`.
- `_segmented` uses radio inputs rather than `aria-pressed` buttons: herb:state can't compute `aria-pressed`, and a checked radio tells the browser and screen readers the same thing. Pass `input_data:` for a `data-herb-set` binding.
- `_stepper` is a real number input with − and + (`stepper_controller.js` steps it and fires `input`/`change`, so herb bindings still see it).

**The shell** (`layouts/_app_header`): wordmark, a `<details>` campaign switcher, tabs and an account button. Inside a campaign (`context_membership`: `Current.membership`, or `@membership` on a seated character's sheet) the tabs are the campaign's (`campaign_tabs`): GM Campaign · Table · Characters · Log; player Campaign · My character · Party · Log (`Membership#seated_character`). Characters and Party point at the campaign page's party section, Log at the session history. Outside a campaign the tabs are the toolkit's, which the footer always lists too.

**Live banner** (`campaigns/_live_banner`): "Live now · Session 8 · Scene 2, The mill fire · 3 at the table" while a session is open, linking to `campaign_play_path`, which sends the GM to the table and a player to their sheet. It shows on campaign pages except the one it links to (`live_banner?`). It updates over its own **`[campaign, :live]`** stream, not `:table`: `:table` carries refresh actions, which would reload pages that don't morph (and wipe a half-typed form). `Campaign#broadcast_table_refresh` sends both, so every boundary updates the banner.

## Roadmap

1. **Pools**: built, with linked phases (`Pool::Phases`: `phases` JSON plus a current `phase` index, entered as the book writes them, e.g. `4d Claws + 4d Tail`; only the current phase rolls, and a 0d phase unlocks the next one; log entries record `phase` and `next_phase`).
2. **Crucibles**: built (see above). Next: path-specific crucibles.
3. **Characters**: built, with the talent catalog and spark spent into rolls (see above).
4. **Campaign play**: the table log is built, and so are sessions and scenes (see "Sessions & scenes"). Action, defense, story, montage and quarrel rolls are built, with spark and assists. Power pools roll as action rolls too. Next ideas: assists on story rolls, and outside help as its own named die.

Open questions: deploy host and domain; whether rolls can be shared without an account.

## Licensing (must keep)

- The footer must credit *Grimwild* by J. D. Maxwell (Oddity Press) under **CC BY 4.0**, say the site is unofficial and not endorsed, and note that the CE text is CC0.
- **Do not** reuse the book's Canva graphic assets or Per Janke's illustrations.
- The book's text may be quoted, but keep it to what a tool needs.

## Agent working notes

- The user develops on macOS (folder `~/Desktop/projects.nosync/grimwilder`) and runs the app there.
- Sandboxed agent environments may be unable to `bundle install` (rubygems.org may be blocked, and the Linux VM ships Ruby 3.0). If you can't boot Rails, still run the Herb linter and the Node tests, and say plainly that the Rails tests weren't run.
- npm packages useful for checks: `@herb-tools/linter@0.11.0`, and `reactionview@0.6.0` (its source shows the client API).
- Don't commit or push unless asked.
- Before a significant decision, check the project plan doc (`claude/toolkit-plan.md` in the Claude project).
