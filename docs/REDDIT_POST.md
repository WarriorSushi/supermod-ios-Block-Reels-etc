# Reddit introduction draft

Check the community's rules before posting, including rules about self-promotion and project links. This is a draft for the project owner to adapt and post; nothing has been posted automatically.

## Suggested title

I open-sourced my experimental iPhone browser for hiding Reels/Shorts and setting scrolling timers (SwiftUI, GPLv3)

## Post

I wanted to open social media for a message or a particular post without automatically ending up in short-video feeds, so I built Supermod.

It is a separate iPhone browser for Instagram, Facebook and public YouTube pages. You choose the supported parts to hide, such as Reels/Shorts or Stories. There is also a Scroll timer: temporarily allow selected features for 1–60 minutes, then hide them again. A small circular countdown stays around the movable controls.

I have made the source available under GPLv3:
https://github.com/WarriorSushi/supermod-ios-Block-Reels-etc

A few honest limitations:

- It works inside Supermod, not in the official apps. It is not a system-wide blocker.
- This is an experimental developer build, not an App Store/TestFlight release. You need a Mac and Xcode to try it.
- Site changes can break filtering, and ad/suggestion recognition is best effort.
- The source contains development subscription code; Debug builds include a no-payment testing option. Production billing is not ready.
- Service permissions, media rights and distribution requirements still need review before a public binary release.

The README has screenshots, setup instructions and the current roadmap. I would especially appreciate feedback on the controls, accessibility, and filter bugs that can be reproduced without sharing private account data. Swift/iOS contributions are welcome too.

## Images

Use the actual [Home](images/home.jpg), [Scroll timer](images/scroll-timer.jpg) and [filter controls](images/filters.jpg) screenshots. They use simulator test settings and contain no personal social account content. Avoid adding unsupported claims such as “blocks every ad,” “approved by Instagram” or “guaranteed to reduce screen time.”
