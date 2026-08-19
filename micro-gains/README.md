# Micro Gains

Micro Gains pings you a few times a day with one tiny bodyweight set. Ten
push-ups. Fifteen air squats. A one-minute plank. You do it, tap Done, and get
on with your day. It is for people who want to be fit but can't get to a gym.

You pick how often (1 to 4 hours), how hard (easy, medium, hard), and which
hours and days are fair game. The app picks the set, rotating through push,
squat, hinge, core, cardio, and mobility so nothing gets hammered and the
first set of the day is never a cold sprint.

## Parts

| Path | What |
| --- | --- |
| [`ios/`](ios/) | UIKit iPhone app. Schedules local notifications on-device, works offline, syncs when it can. |
| [`server/`](server/) | Cloudflare Worker + D1. Device settings, set log, streaks and history, exercise catalog. |
| [`SPEC.md`](SPEC.md) | The contract between the two. Change both sides when you change it. |
| [`RESEARCH.md`](RESEARCH.md) | The exercise-science behind the defaults and selection rules, with sources. |
| [`catalog.json`](catalog.json) | The 30-exercise catalog. Bundled in the app and seeded into D1. |

## Why the defaults are what they are

The short version of RESEARCH.md: a few minutes a day of genuinely vigorous
movement in sub-minute bouts tracks with large mortality reductions
(Stamatakis 2022), every trial that worked used about three bouts a day, and
nothing under an hourly interval has evidence or notification tolerance behind
it. So the default is every 2 hours from 09:00 to 19:00, each pattern at most
twice a day with a 3-hour gap, and the copy in each ping rotates because
identical prompts stop working within a month.

## Auth

There isn't any, on purpose. The app generates a UUID once, keeps it in the
Keychain, and sends it as `X-Device-Id`. Same posture as Read the Bible's reader
cookie. Erase my data deletes the server rows and rotates the UUID.

## Develop

```sh
cd server && npm install && npm run db:migrate:local && npm run db:seed:local && npm run dev
cd ios && xcodegen generate && open MicroGains.xcodeproj
```

Each part's README has the details.
