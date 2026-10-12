# Visirupt website

Public static landing page for the Visirupt developer project. It describes verified native windowed gameplay and explicitly separates future VR work and an unavailable public installer. No signup backend, tracker, external font or game media is included.

The page is served by two nonroot, read-only nginx containers in the `visirupt` namespace, using the existing nginx ingress and `letsencrypt-prod` cluster issuer. Separate apex/www certificates allow each name to complete independently during initial DNS propagation. The nginx image digest matches the already deployed tiptontek site. ConfigMaps hold static content and nginx configuration; no image rebuild or registry credentials are required.

Run `./deploy.sh` with the intended kubeconfig. It applies only Visirupt resources and restarts its own deployment so updated ConfigMaps are loaded. DNS uses the `tip` AWS profile: apex and www A records point to the existing public ingress address. The included DNS change is the explicit initial publication operation; deployment does not modify DNS automatically.

A dedicated `www` ingress redirects HTTP and HTTPS directly to canonical `https://visirupt.com`, preserving path/query. Explicit Certificate resources keep their issuance independent. The same-origin script controls only a labeled concept illustration; it does not run the native game or demonstrate VR. Confirm rollout readiness, certificate readiness, valid HTTPS, root-page hash and both HTTP/www redirects after deploying.
