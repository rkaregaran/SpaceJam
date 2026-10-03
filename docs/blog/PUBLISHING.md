# Publishing the rzkr.dev post

The article is a draft for the existing blog, not a new site. Review
`apple-let-us-set-animation-speed.md` before publishing it.

Suggested slug: `apple-let-us-set-animation-speed`

Suggested excerpt: "I want to keep the desktop slide and choose how quickly it
happens. SpaceJam is my workaround. Apple should make this a native setting."

The live site uses Astro and Markdown in `src/content/writing`. Add its standard
frontmatter with `draft: true`, copy the settings image into `public/images/spacejam`,
and use `/images/spacejam/settings.png` in the article. Drafts are visible in
development and excluded from the production build. The text currently
describes downloads as being prepared. Once a signed release is live, change
that paragraph to installation instructions and link to it.

Do not publish a download promise before the release exists. No production
site content has been published by the local draft.
