// The site's name, written once: the home page's heading and every page's
// <title> read SITE_NAME. A site made from this repository gets it rewritten
// to its own name, as a JSON string so that any name (an apostrophe or an
// ampersand included) stays a valid one, so keep it a literal on one line.
export const SITE_NAME = "SvelteKit Auth Example"

/** A page's <title>: the page, then the site. The home page is the site. */
export function pageTitle(page?: string): string {
  return page ? `${page} | ${SITE_NAME}` : SITE_NAME
}
