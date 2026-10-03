# Publishing the rzkr.dev post

The article is a draft for the existing blog, not a new site. Review
`apple-let-us-set-animation-speed.md` before publishing it.

Suggested slug: `apple-let-us-set-animation-speed`

Suggested excerpt: "Switching between desktop spaces feels too slow. SpaceJam speeds it up, but macOS should let users adjust animation speed directly."

The live site uses Astro and Markdown in `src/content/writing`. Add its standard
frontmatter with `draft: true`, copy the settings image into `public/images/spacejam`,
and use `/images/spacejam/settings.png` in the article. Drafts are visible in
development and excluded from the production build. Add a download link once
a signed release is available.

Do not publish a download promise before the release exists. No production
site content has been published by the local draft.
