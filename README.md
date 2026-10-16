# Between Stops — Library Kiosk

The kiosk half of **Between Stops**, a shared library that lives on NSW trains. Readers reserve a book in the [phone app](https://rjschweitz.github.io/test), then scan a QR code at the kiosk in the carriage and a locker door pops open with their book inside.

## Try it

| | Link |
|---|---|
| **Web kiosk** (runs in any browser, best on an iPad in landscape) | https://jacob9170.github.io/between-stops-kiosk/ |
| **Pass maker** (open on your phone to make a QR pass) | https://jacob9170.github.io/between-stops-kiosk/pass/ |

Open the pass maker on your phone, reserve a book, then hold the QR up to the kiosk's camera. No phone handy? Use the demo passes on the kiosk's home screen.

**Tip for iPads:** open the kiosk in Safari, tap Share → Add to Home Screen, and launch it from there for a full screen kiosk.

## Features

- **Zero tap collecting**: the camera is always scanning on the home screen, with an on-screen camera status
- **Step indicator** on collect (Scan your pass → Door opens → Take your book) and return
- **6 digit code or 4 digit quick code** entry for when the QR won't scan
- **Locker animation**: doors light up in sequence, the right one swings open and the book flies out
- **Returns** check the scanned book against what's out on loan and name it on screen ("You returned Orchard Hours"). Scan the barcode, pick from the list of books on loan, or type the 13 digit number. Then:
  - *I've finished reading it*: star rating, tags and a written review, shown to the next reader
  - *I'm still reading it*: save the page you're up to, and next time you collect it the kiosk says "Jump back in at page 142"
- **Browse the shelf** (no phone or reservation needed) with fuller descriptions, ratings, reviews, the book's journey, and *Surprise me* that respects the chosen category
- **Step-by-step tour** from Home or How it works, with Back, Next and Skip
- Live **next stop** bar, **larger text** mode, call the guard, report a problem
- **Idle timeout** back to an animated attract screen
- **Crew mode**: hold the logo for 2 seconds, PIN `2468`

### Demo codes

| Code | What happens |
|---|---|
| `482 913` or quick code `1107` | Alex's reservation, with a saved page |
| `105 277` or quick code `1258` | Sam's reservation |
| `660 021` | Expired pass |
| `777 314` | Book is on a different train |

## Two versions

| Folder | What it is |
|---|---|
| `index.html` | Web kiosk (HTML/CSS/JS, no build step). Hosted on GitHub Pages. |
| `pass/` | Phone pass maker. Hosted on GitHub Pages. |
| `BetweenStopsKiosk.xcodeproj` + `BetweenStopsKiosk/` | Native SwiftUI iPad app. Open in Xcode and press Run. |

## Prototype notes

There's no shared server, so the phone and kiosk can't talk to each other. To get around that, QR passes carry the book ID, and the first two digits of a quick code identify the book. In the web kiosk, saved pages and reviews are stored in the browser so they survive a reload.

UTS Advanced Interaction Design, 2026.
