# Visirupt website

Public landing page for native Mac apps and games on Vision Pro. It describes verified native windowed gameplay and distinguishes future VR work and the unavailable public installer. The top navigation and developer section link to the public GitHub repository. The footer links to Tiptontek.

Two anonymous community polls collect desired software categories and development priorities. Results are shared across visitors and start at zero. A functional, Secure/HttpOnly/SameSite cookie is created only when voting; its random token is hashed in SQLite. No names, emails, IP addresses or request logs are stored by the poll service. Clearing cookies or using another browser permits another vote; these are informal community polls, not an authenticated survey. Same-origin checks, request-size limits and nginx rate limiting bound ordinary abuse.

## Deployment

`make verify` checks the page, JavaScript and deployment script, and runs the poll tests against temporary databases. `make deploy` applies only Visirupt resources. Static content and poll source are ConfigMaps; official nginx and Python images are pinned by digest. No image rebuild or registry credentials are required.

Two nonroot, read-only nginx pods serve the page. One Python/SQLite poll pod uses a 1 GiB persistent volume claim with a Recreate deployment strategy; votes survive pod replacements. Deployments restart these Visirupt services to load updated configuration. A backend restart briefly makes polls unavailable. The existing nginx ingress and `letsencrypt-prod` issuer provide TLS. Dedicated www ingress redirects HTTP/HTTPS directly to `https://visirupt.com`, preserving path/query.

DNS was published with AWS profile `tip` to the existing ingress IP; deploying does not modify DNS. Verify rollout readiness, both certificates, HTTPS, `/api/polls`, links and redirects after deployment. The poll API is same-origin under `/api/`; no signup backend, tracker, external font or game media is included.

## Vote storage and recovery

Keep `visirupt-polls-data` and its underlying persistent volume when redeploying or rolling back. Do not delete the namespace/PVC to update the site. The cluster's OpenEBS hostpath storage survives pod replacement but is not a node-loss backup. For a consistent backup, use SQLite's backup API inside the backend pod and copy its output out before infrastructure maintenance. Poll definitions use stable IDs; changing question meaning needs a new ID rather than reusing existing votes. There is no public administration or deletion endpoint. Do not cast test votes in production; use the temporary-database tests or an isolated preview instead.
