# Changelog

What changed in Grimwilder, one entry per merged pull request, grouped by the day it merged (UTC), newest first.

## 2026-11-03

- **Polls**: from the GM table's new "Share with the table" fold, the GM asks the players a question, written answers or a set of choices. Each player answers in a pop-up on whatever campaign page they're on, and only the GM sees the answers, live, until the poll is closed. (PR link to come)
- **Handouts**: the GM shares an image (a map, a letter, a diagram) with an optional caption. It lands in the table chat, and only people at that table can open it. (PR link to come)
- **Feedback**: an admin can turn on a Feedback button for an account; it sends what they think along with the page they were on. Admins read it under Admin › Feedback and can copy it all as Markdown for an AI. ([#87](https://github.com/phChun/grimwilder/pull/87))
- **Searchable dropdowns**: every dropdown is drawn in Grimwilder's own style, and long ones (time zones, paths, talents) have a search box. They work from the keyboard too. ([#86](https://github.com/phChun/grimwilder/pull/86))
- **Early access**: new accounts start on the Early access plan, with no limits on how many campaigns they run or play in. ([#85](https://github.com/phChun/grimwilder/pull/85))
- **Scene blocks**: group your prepared scenes by where the players might go ("The castle"), each block with its own notes. Start a session on a block and its scenes come first; any prepared scene can still be pulled into any session. ([#85](https://github.com/phChun/grimwilder/pull/85))
- **A new way to start a scene**: from the GM table, a modal lists this session's block, the loose scenes and the other blocks; start one as written in one tap, adjust it first, or make a new one. ([#85](https://github.com/phChun/grimwilder/pull/85))
- **Running clocks** on the GM table: how long the session and the current scene have run, ticking beside the scene's title. ([#85](https://github.com/phChun/grimwilder/pull/85))
- **Scene notes at the table**: while a scene is on, its notes (and its block's) show in the GM table's scene bar. ([#85](https://github.com/phChun/grimwilder/pull/85))
- **Journals**: each player keeps a journal at a campaign, a page per session or for the stretch between, with *italics* and **bold** as in the chat. The GM can read it unless the player keeps it private. ([#85](https://github.com/phChun/grimwilder/pull/85))

## 2026-11-02

- **Chat opens on Table talk** on the GM table and on character sheets; the campaign page still shows everything. ([#84](https://github.com/phChun/grimwilder/pull/84))
- **Releases deploy**: merging no longer ships the site; publishing a GitHub release does, and admin's Site stats shows the release running. ([#84](https://github.com/phChun/grimwilder/pull/84))
- **Turn the invite link off**: in settings, the GM can switch the invite link off so no one new joins, and back on later. ([#83](https://github.com/phChun/grimwilder/pull/83))
- **Game schedules**: set when your table plays (every week or few, or monthly like "first Saturday"), skip or move a date, add one-offs, and everyone sees the next game on the campaigns list, the campaign page and the GM table, in their own time zone. ([#82](https://github.com/phChun/grimwilder/pull/82))
- **On hold**: when a plan runs fewer campaigns than you have, the most recently played keeps going and the rest wait, with chat and sheets still open. Choose which to play from the campaigns list. ([#81](https://github.com/phChun/grimwilder/pull/81))
- **Done is now Archived**: an archived campaign stays to read, and nothing new is played there. ([#80](https://github.com/phChun/grimwilder/pull/80))
- **Archive from the campaigns list**: each campaign you run has a ⋯ menu to archive or unarchive it. ([#80](https://github.com/phChun/grimwilder/pull/80))
- **Switching backgrounds swaps their wises**: picking another common background replaces the wises the last one filled in, and keeps any you wrote. A filled-in background box offers the whole list again, not just the one already there. ([#79](https://github.com/phChun/grimwilder/pull/79))

## 2026-10-30

- **Copy for an AI** includes characters up for grabs. ([#78](https://github.com/phChun/grimwilder/pull/78))
- **Copy for an AI**: the GM can copy the campaign and the party as Markdown, to hand to an AI that helps tell the story. ([#77](https://github.com/phChun/grimwilder/pull/77))
- **The home page** says what Grimwilder keeps track of, rather than calling Grimwild fiddly. ([#76](https://github.com/phChun/grimwilder/pull/76))
- **The Respite fold-out** shows Rest again: it was squeezed beside the close button. ([#75](https://github.com/phChun/grimwilder/pull/75))
- **Links look good when shared**: pasting a Grimwilder link in Discord, Slack or iMessage shows a preview card, and an invite link names its campaign and GM. ([#74](https://github.com/phChun/grimwilder/pull/74))
- **Search engines** get a sitemap and stay off signed-in pages and invite links. ([#74](https://github.com/phChun/grimwilder/pull/74))
- **Expanded downtime**, an optional rule: the GM picks how each character spends downtime (rest, plan ahead, pursue a goal, unwind or venture), and it replaces carousing. ([#73](https://github.com/phChun/grimwilder/pull/73))
- **Clearer downtime pools**: the form says every campaign pool rolls before the one you pick is depleted. ([#73](https://github.com/phChun/grimwilder/pull/73))
- **New crucibles**: the solo rules' consequences (rolled on a d8) and a random potion. ([#73](https://github.com/phChun/grimwilder/pull/73))
- **Wild Shape** lists the book's example wild talents. ([#73](https://github.com/phChun/grimwilder/pull/73))
- **A new home page** that shows what Grimwilder does at the table and on a sheet, with an example of play. ([#72](https://github.com/phChun/grimwilder/pull/72))
- **I'm interested**: while sign-ups are closed, leave your email, how you'd play and a note, and we'll be in touch. ([#72](https://github.com/phChun/grimwilder/pull/72))
- **Admin**: an Interested list to make accounts from, and search and pages on every list. ([#72](https://github.com/phChun/grimwilder/pull/72))
- **Sign-in codes are limited per email address** too, so no one can flood an inbox. ([#72](https://github.com/phChun/grimwilder/pull/72))
- **Search crucibles** by name, blurb or any word they roll, like the talent catalog. ([#69](https://github.com/phChun/grimwilder/pull/69))
- **Crucibles follow the Community Edition**: CE's Extra Wises, atmospherics for each season, all seven criminal-history reactions, and new crucibles for magitechnobabble, a paladin's tenets, finding treasure and potion qualities. ([#69](https://github.com/phChun/grimwilder/pull/69))
- **Crucible tables and results spread out** by how many tables there are: one has the page's width, with bigger cells, and two share it. A roll leads with the words smashed together, then a row per table (its name, the dice, the readings); a single reading is ember text, not a button. ([#69](https://github.com/phChun/grimwilder/pull/69))
- **Talent summaries are written for choosing**: what each talent lets you do, how often, and the catch. ([#70](https://github.com/phChun/grimwilder/pull/70))
- **Trap Making is retired**, as the Community Edition removed it. Sheets that have it keep it. ([#70](https://github.com/phChun/grimwilder/pull/70))
- **The Community Edition.** Talents follow its text and summaries, and the footer names it. Page numbers are still Preview 6's until they're re-checked. ([#68](https://github.com/phChun/grimwilder/pull/68))
- **Pact is now Hex**, the Warlock's core talent. Saved characters keep it. ([#68](https://github.com/phChun/grimwilder/pull/68))
- **Shared Soul is Summoner only, Bailiwick Witch only.** Sheets that already have them keep them. ([#68](https://github.com/phChun/grimwilder/pull/68))
- **Downtime depletes a campaign pool**: after the rolls, the GM picks one on the form and it runs out. ([#68](https://github.com/phChun/grimwilder/pull/68))

## 2026-10-28

- **Sign-ins last six hours**, then you sign in again with a code or a passkey. ([#61](https://github.com/phChun/grimwilder/pull/61))
- **Up-for-grabs characters** no longer say "played by" the GM who holds them. ([#61](https://github.com/phChun/grimwilder/pull/61))
- **Crucibles:** each table's reading sits side by side when there's room, with a rule between them. ([#61](https://github.com/phChun/grimwilder/pull/61))
- **The footer spans the page** in two halves: the toolkit's links on the left, the legal notice on the right. ([#61](https://github.com/phChun/grimwilder/pull/61))
- **The GM can block a player** from settings: they're removed, and the invite link won't let them back in until they're unblocked. Remove still lets them rejoin with the link. ([#61](https://github.com/phChun/grimwilder/pull/61))
- **Secret rolls.** The GM's story roll for no one in particular can be "Only I see it", and a player's ability roll "Only the GM sees it". GM-only rolls are outlined in dashed purple, like whispers. ([#59](https://github.com/phChun/grimwilder/pull/59))
- **The campaign page is an overview**: the hero, the party, what looms and "Previously on…". Players roll the shared pools on their sheets, and only the GM calls for rolls. ([#58](https://github.com/phChun/grimwilder/pull/58))
- **Campaign settings are the GM's.** Players leave from the campaign page. ([#57](https://github.com/phChun/grimwilder/pull/57))
- **Chat: Show decides where you send.** Private conversations with the GM or another player, and unread markers. ([#55](https://github.com/phChun/grimwilder/pull/55), [#56](https://github.com/phChun/grimwilder/pull/56))
- **Chat: speak as** a character, an NPC or the narrator, a "Chat" filter, and no separate game-event box. ([#54](https://github.com/phChun/grimwilder/pull/54))
- **Campaign settings** get a Characters section, and the optional rules a section of their own. ([#53](https://github.com/phChun/grimwilder/pull/53))
- **Chat is taller**, and the composer has no roll button. ([#52](https://github.com/phChun/grimwilder/pull/52))
- **The roll setup opens in a modal**, so the sheet doesn't shift. ([#51](https://github.com/phChun/grimwilder/pull/51))
- **Vex** on the Harm card: fight, flight, freeze or freakout. ([#50](https://github.com/phChun/grimwilder/pull/50))
- **Fix:** the session history before any session. ([#49](https://github.com/phChun/grimwilder/pull/49))

## 2026-10-27

- **Scene prep.** The GM writes scenes ahead and starts one from them. ([#48](https://github.com/phChun/grimwilder/pull/48))
- **Talent cards** say "Roll it in a session", and the ⋯ menu sits beside the chevron. ([#47](https://github.com/phChun/grimwilder/pull/47))
- **Talents fold** to their name and summary on the character sheet. ([#46](https://github.com/phChun/grimwilder/pull/46))
- **Talent picker:** add several, then save. ([#45](https://github.com/phChun/grimwilder/pull/45))
- **Pick the level** when making a character. ([#44](https://github.com/phChun/grimwilder/pull/44))
- AGENTS.md: the roadmap as it stands. ([#43](https://github.com/phChun/grimwilder/pull/43))
- **Crucibles:** the monster pages' word grids. ([#42](https://github.com/phChun/grimwilder/pull/42))
- **Arcana additions** and the bard's song. ([#41](https://github.com/phChun/grimwilder/pull/41))
- **Optional rules:** Bulwark's rework, Coins, Reset conditions, and rule pools made at once. ([#40](https://github.com/phChun/grimwilder/pull/40))
- **Reminders:** picks to make on party cards, and a note on "[X Only]" talents. ([#39](https://github.com/phChun/grimwilder/pull/39))
- **The /roll page** gets the talent dice rules. ([#38](https://github.com/phChun/grimwilder/pull/38))
- **Crucibles:** the monster pages' d6 tables and the vassal's aspects. ([#37](https://github.com/phChun/grimwilder/pull/37))
- **Optional rules as campaign settings** (Preview 6). ([#36](https://github.com/phChun/grimwilder/pull/36))
- **Talent features:** Oathsworn's tenets, Monster Menagerie, Archivist and path builders. ([#35](https://github.com/phChun/grimwilder/pull/35))
- **Fixes after Preview 6:** undoing stat progression, level 1 links. ([#34](https://github.com/phChun/grimwilder/pull/34))
- **Stat progression** goes only to 3, as the book says. ([#33](https://github.com/phChun/grimwilder/pull/33))
- **Preview 6, phases 4 and 5:** the Adventurer, Oathbreaker and optional rules. ([#32](https://github.com/phChun/grimwilder/pull/32))
- **Preview 6, phase 3:** talent mechanics. ([#31](https://github.com/phChun/grimwilder/pull/31))
- **Preview 6, phase 2:** Mastermind and Expertise's new skills, with saved characters moved across. ([#30](https://github.com/phChun/grimwilder/pull/30))
- **Preview 6, phase 1:** page numbers, talent text and lists. ([#29](https://github.com/phChun/grimwilder/pull/29))
- Design tokens replace the old CSS aliases. ([#28](https://github.com/phChun/grimwilder/pull/28))
- **Crucibles, path builders and legacy talents.** ([#27](https://github.com/phChun/grimwilder/pull/27))
- **Table rules:** tick pools, assists on story rolls, named help and spark from bonds. ([#26](https://github.com/phChun/grimwilder/pull/26))
- **The optional stat progression rule.** ([#25](https://github.com/phChun/grimwilder/pull/25))
- **Cast:** a button on spellcasting talents. ([#24](https://github.com/phChun/grimwilder/pull/24))
- **Talent trackers:** what talents keep track of between rolls. ([#23](https://github.com/phChun/grimwilder/pull/23))
- **Dice rules talents bend:** reckless rolls, Teamwork, twists and panache. ([#22](https://github.com/phChun/grimwilder/pull/22))
- **After the roll:** talents that change a roll once it's made. ([#21](https://github.com/phChun/grimwilder/pull/21))
- **Talent bonuses:** tick the talents that add dice to a roll. ([#20](https://github.com/phChun/grimwilder/pull/20))
- The rules edition is named: *Grimwild* CE Preview 6. ([#19](https://github.com/phChun/grimwilder/pull/19))

## 2026-10-26

- **Talent choices, phase 3:** arcana on the character sheet. ([#18](https://github.com/phChun/grimwilder/pull/18))
- **Talent choices, phase 2:** picks from crucibles and from other picks. ([#17](https://github.com/phChun/grimwilder/pull/17))
- **Talent choices, phase 1:** pick what a talent asks for. ([#16](https://github.com/phChun/grimwilder/pull/16))

## 2026-10-25

- Ruby 4.0.9. ([#15](https://github.com/phChun/grimwilder/pull/15))

## 2026-10-24

- **Plans:** Free, Patron and Tester, assigned by an admin. ([#14](https://github.com/phChun/grimwilder/pull/14))
- Mail credentials rotated. ([#13](https://github.com/phChun/grimwilder/pull/13))
- **A dice mark and icon** for Grimwilder. ([#12](https://github.com/phChun/grimwilder/pull/12))
- Getting ready to open-source under O'Saasy. ([#11](https://github.com/phChun/grimwilder/pull/11))
- Last sign-in is kept on the account, since signing out deletes sessions. ([#10](https://github.com/phChun/grimwilder/pull/10))
- **Admin:** an admin flag and an admin area at /admin. ([#9](https://github.com/phChun/grimwilder/pull/9))
- The trait and desire you aren't are set apart in a muted rose. ([#8](https://github.com/phChun/grimwilder/pull/8))
- Production errors are emailed, and how production works is written down. ([#7](https://github.com/phChun/grimwilder/pull/7))
- Mail goes to Resend on port 2587. ([#6](https://github.com/phChun/grimwilder/pull/6))
- Sign-in codes are sent through Resend. ([#5](https://github.com/phChun/grimwilder/pull/5))
- New emails are told sign-ups are closed. ([#4](https://github.com/phChun/grimwilder/pull/4))
- **Live at grimwilder.com:** ready to deploy. ([#3](https://github.com/phChun/grimwilder/pull/3))

## 2026-10-22

- Dependencies: sqlite3 2.10.1 ([#2](https://github.com/phChun/grimwilder/pull/2)) and Rails `main` at `7e3828a` ([#1](https://github.com/phChun/grimwilder/pull/1)).
