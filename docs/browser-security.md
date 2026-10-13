# Browser security policy

The site is hosted on GitHub Pages, so the application cannot freely set arbitrary HTTP response headers. Browser hardening is therefore split into controls that are valid in HTML and controls that require an upstream edge/CDN.

## Implemented in HTML

The Nuxt global head includes:

- `Content-Security-Policy` via `http-equiv`
- `Referrer-Policy` via the standard `referrer` meta element

The CSP currently allows the resources required by the static Nuxt application and Google Analytics while denying plugins and mixed-content downgrade paths.

## CSP policy

```text
default-src 'self'
base-uri 'self'
object-src 'none'
script-src 'self' 'unsafe-inline' https://www.googletagmanager.com
style-src 'self' 'unsafe-inline'
img-src 'self' data: https:
font-src 'self' data:
connect-src 'self' https://www.google-analytics.com https://region1.google-analytics.com https://www.googletagmanager.com
form-action 'self'
upgrade-insecure-requests
```

`'unsafe-inline'` is currently required because the Nuxt 2 generated output contains inline bootstrap/metadata scripts and styles. Remove it when the Nuxt 3 migration makes nonce/hash based CSP practical.

## Controls that require HTTP response headers

The following should not be treated as enforced by HTML meta tags:

- `frame-ancestors`
- `X-Content-Type-Options: nosniff`
- `Permissions-Policy`
- HSTS policy management

If these controls are required, place an edge layer such as Cloudflare in front of GitHub Pages and configure the response headers there.

## Validation

After deployment, verify that:

1. the site renders without CSP violations that break functionality;
2. Google Analytics requests are allowed when GA is configured;
3. no unexpected third-party origins are required;
4. browser developer tools do not report blocked first-party assets.

When a new third-party script, image host, API, or font provider is introduced, update the CSP deliberately rather than broadening it to unrestricted sources.
