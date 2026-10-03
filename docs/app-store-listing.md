# App Store listing — draft

Paste into App Store Connect. Limits are Apple's; counts are checked below each field.

## Identity

| Field | Value |
|---|---|
| Name (30) | `Personal` — if taken: `Personal: Private CRM` |
| Subtitle (30) | `Remember people, follow up` |
| Bundle ID | `com.mjcxstudio.personalCrm` |
| SKU | `personal-ios` |
| Primary category | Productivity |
| Secondary category | Business |
| Price | paid up front, one tier between $0.99 and $4.99; no in-app purchases |
| Devices | iPhone only |
| Copyright | `2026 Leonard Davidson` |
| Age rating | answer "None" to every questionnaire item → 4+ |

## URLs

| Field | Value |
|---|---|
| Privacy Policy URL | https://personal-api.mjcxstudio.com/privacy |
| Support URL | https://personal-api.mjcxstudio.com/support |
| Marketing URL (optional) | https://github.com/leoner11/personal |
| Terms | https://personal-api.mjcxstudio.com/terms (link it at the end of the description; keep Apple's standard EULA selected) |

## Promotional text (170)

A private CRM for the people in your life and work. Everything stays on your phone unless you choose to sync. No ads, no tracking, no subscription.

## Description (4000)

Personal is a small, private CRM for one person: you.

It keeps track of the people you know, when you last spoke, what you promised, and what is coming up, so that following up stops depending on your memory.

CAPTURE IN SECONDS
Add someone the moment you meet them: a name, their WhatsApp or WeChat, and the occasions they celebrate. It works with no signal and no account.

TODAY
One screen for the day: your meetings, the tasks that are due, and the people you told yourself to get back to.

PEOPLE
Everyone you have added, ordered by how long it has been since you were last in touch. Open a person to message them on WhatsApp or WeChat, log a contact, and see their notes, meetings and money in one place.

OCCASIONS
Tag people with the festivals they keep, such as Chinese New Year, Lebaran, Deepavali, Christmas or your own, and Personal reminds you before each one with your greeting ready to send.

CALENDAR, TASKS AND NOTES
Meetings, tasks and notes attach to a person or a project, so the context is there when you open either. Add a meeting to your phone's calendar with one tap.

PROJECTS AND MONEY
Deals, joint ventures, clients and leads with a free-text status, and a simple cashflow: what has come in, what has gone out, and what you expect.

PRIVATE BY DESIGN
• Works fully on your device. No account is needed.
• Nothing leaves your phone unless you create an account to sync.
• No ads, no analytics, no tracking.
• Delete your account and everything synced to it from inside the app, at any time.

SYNC IF YOU WANT IT
Create a free account inside the app to sync between your phone and the free Mac and Windows apps. Personal is open source, so you can also run your own sync server.

ONE PRICE
Pay once. No subscription and no in-app purchases.

Terms of Service: https://personal-api.mjcxstudio.com/terms
Privacy Policy: https://personal-api.mjcxstudio.com/privacy

## Keywords (100, comma-separated, no spaces)

crm,contacts,relationships,follow up,networking,notes,tasks,cashflow,whatsapp,wechat,reminder,deals

## What's New (first version)

First release on the App Store.

## Screenshots

`shots/appstore/*.png` (not in git), 1320×2868, iPhone 6.9" slot. Suggested order: today, people, capture, calendar, money, projects, notes. All data in them is invented.

## App Privacy label

"Data used to track you": none. Tracking: No.

Collected only when someone creates an account, all **linked to the user**, purpose **App Functionality** only:

| Apple data type | What it is here |
|---|---|
| Contact Info → Email Address | the account email |
| Contacts | the people the user adds (names, WhatsApp numbers, WeChat IDs) |
| User Content → Other User Content | notes, tasks, meetings, projects, occasions |
| Financial Info → Other Financial Info | money entries |

Not collected: location, identifiers, usage data, diagnostics, purchases, browsing or search history, health, sensitive info.

## App Review information

Sign-in required: **No** is the accurate answer for using the app, but give the demo account anyway so sync can be checked.

- Demo account: create one in the app before submitting and enter its email and password in App Store Connect only (never in this repository). Add a few people to it so the reviewer sees data after signing in.
- Contact: your name, phone and email.

Notes for the reviewer:

> Personal is a personal CRM that works entirely on the device. No account is required: the reviewer can add people, tasks, meetings, notes and money entries straight away from the Capture tab.
>
> An account is optional and only enables sync with our server and the companion desktop apps. To test it: Review tab → Account → sign in with the demo account above. Accounts are free to create in the app; nothing is sold inside the app, and the app is a one-time paid download.
>
> Account deletion (guideline 5.1.1(v)): Review → Account → Delete account. It asks for the password and removes the account and all synced data from the server immediately.
>
> Password reset: Review → Account → Forgot password? sends a six-digit code by email.
>
> Permissions: notifications are used for on-device reminders only (no push service). Calendar access is requested only when the user taps "Add to calendar" on a meeting; the app never reads the calendar. The WhatsApp and WeChat buttons open those apps with a message for the user to send; the app does not read chats or the device's address book.
>
> Encryption: HTTPS and the system Keychain only (ITSAppUsesNonExemptEncryption = NO).
