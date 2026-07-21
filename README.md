
## AAP Self Service Role

Install and configure the Red Hat AAP Self Service Portal on OpenShift using an Ansible role and Helm chart.

Tested with Ansible Automation Platform 2.6 and the Self-Service Automation Portal (GA with AAP 2.6).

### Quick start

```bash
ansible-galaxy collection install -r collections/requirements.yml
pip install -r python-requirements.txt
oc login <OpenShift_API_URL>
cp var_files/portal.yml.example var_files/aap26-portal.yml
# edit var_files/aap26-portal.yml, extract plugins (see Step 3)
./install-portal.sh
```

Run preflight checks only before a full install:

```bash
TAGS=preflight ./install-portal.sh
```

---

## Repository Structure

```
aap-self-service-role-fork/
├── deploy-aap-selfservice.yml
├── collections/requirements.yml
├── python-requirements.txt
├── var_files/                          # Per-environment vars (gitignored)
│   └── portal.yml.example              # Committed template — copy and customize
├── plugins/                            # Plugin bundles by AAP version
│   └── aap2x/
│       └── self-service-automation-portal-plugins-x.y.z.tar.gz
└── self-service/                       # Ansible role
    ├── defaults/
    ├── files/helm/values.yml
    └── tasks/
```

---

## Step 1: Install Dependencies

Install Ansible collections:

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

Install Python dependencies:

```bash
pip install -r python-requirements.txt
```

Log in to OpenShift before running the playbook:

```bash
oc login <OpenShift_API_URL>
```

---

## Step 2: Create a Vars File

Copy the committed example and customize it for your environment:

```bash
cp var_files/portal.yml.example var_files/aap26-portal.yml
```

Files matching `var_files/*.yml` are **not** committed to version control. See `var_files/portal.yml.example` for all supported scenarios, optional settings, and example run commands.

Minimal `var_files/aap26-portal.yml`:

```yaml
---
aap_host: aap.example.com          # hostname or full URL (https:// added automatically)
aap_username: admin
aap_password: your_aap_admin_password
openshift_namespace: aap26-self-service
plugin_root_dir: "{{ playbook_dir }}/plugins/aap26/extracted"

# Optional: GitHub/GitLab PATs for SCM integration
# github_token: ghp_your_github_token
# gitlab_token: glpat-your_gitlab_token

# Optional: download plugins from Red Hat instead of manual extract
# download_plugins: true
# rhsm_offline_token: your_rhsm_offline_token
# aap_version: "2.6"

# Optional: recreate OAuth app on each run
# recreate_oauth_app: false
```

Required variables:

| Variable | Description |
|----------|-------------|
| `aap_host` | AAP controller route hostname or URL |
| `aap_password` | AAP admin password |
| `openshift_namespace` | OpenShift project for the portal |
| `plugin_root_dir` | Directory containing extracted plugin files (unless using `download_plugins`) |

Optional variables are defined in `self-service/defaults/main.yml`.

The role also:

- Ensures the AAP organization exists (`ensure_aap_organization`, default `true`)
- Enables `ALLOW_OAUTH2_FOR_EXTERNAL_USERS` in AAP
- Normalizes `aap_host` to a full `https://` URL for OpenShift secrets
- Creates the OAuth application and API token automatically

---

## Step 3: Add Dynamic Plugins

Choose one of two methods.

### Option A: Manual download and extract

Download the **Ansible self-service automation portal Setup Bundle** from the [Red Hat AAP Product Software downloads](https://access.redhat.com/downloads/content/480) page.

Place the bundle under a version-specific directory:

```
plugins/aap26/self-service-automation-portal-plugins-2.1.4.tar.gz
```

Extract before running the playbook. `plugin_root_dir` must point at the **extracted** files:

```bash
mkdir -p plugins/aap26/extracted
tar --exclude='*code*' -xzf \
  plugins/aap26/self-service-automation-portal-plugins-2.1.4.tar.gz \
  -C plugins/aap26/extracted
```

After extraction you should see `.tgz` and `.integrity` files such as:

```
ansible-plugin-backstage-rhaap-dynamic-x.y.z.tgz
ansible-plugin-backstage-rhaap-dynamic-x.y.z.tgz.integrity
ansible-plugin-scaffolder-backend-module-backstage-rhaap-dynamic-x.y.z.tgz
ansible-plugin-scaffolder-backend-module-backstage-rhaap-dynamic-x.y.z.tgz.integrity
```

### Option B: Automatic download from RHSM

Set in your vars file:

```yaml
download_plugins: true
rhsm_offline_token: your_rhsm_offline_token
plugin_root_dir: "{{ playbook_dir }}/plugins/aap26/extracted"
```

Obtain an offline token from [Red Hat's RHSM API instructions](https://access.redhat.com/articles/3626371). The role downloads, extracts, and uses the bundle automatically.

Adjust `aap_version`, `rhel_version`, and `release_arch` in defaults if targeting a different AAP release bundle.

---

## Step 4: Run the Ansible Role

A vars file **must** be passed on the command line. See `var_files/portal.yml.example` for additional run patterns and tagged partial runs.

```bash
ansible-playbook deploy-aap-selfservice.yml -e @var_files/aap26-portal.yml
```

With automatic plugin download:

```bash
ansible-playbook deploy-aap-selfservice.yml \
  -e @var_files/aap26-portal.yml \
  -e download_plugins=true \
  -e rhsm_offline_token=your_token
```

macOS with a virtualenv:

```bash
ansible-playbook deploy-aap-selfservice.yml \
  -e @var_files/aap26-portal.yml \
  -e "ansible_python_interpreter=$(which python)"
```

Re-run specific steps with tags:

```bash
ansible-playbook deploy-aap-selfservice.yml \
  -e @var_files/aap26-portal.yml \
  --tags build_plugin,deploy_plugin
```

Override individual variables inline:

```bash
ansible-playbook deploy-aap-selfservice.yml \
  -e @var_files/aap26-portal.yml \
  -e openshift_namespace=my-other-namespace
```

---

## What the Role Does

| Step | File | Tag(s) | Description |
|------|------|--------|-------------|
| Validate vars | `validate.yml` | `validate` | Checks required variables |
| Normalize AAP URL | `prep.yml` | `prep` | Builds `aap_hostname` and `aap_host_url` facts |
| Preflight | `preflight.yml` | `preflight`, `build_plugin`, `helm`, `deploy_plugin` | Fail-early checks (see below) |
| AAP platform setup | `aap_setup.yml` | `aap_setup`, `create_oauth` | Ensures org, enables external OAuth tokens, optional OAuth delete |
| Create OAuth2 app | `oauth.yml` | `create_oauth` | Registers an OAuth2 application in AAP |
| Create AAP token | `create_token.yml` | `create_token` | Generates a write-scoped API token |
| Create namespace | `namespace.yml` | `create_namespace` | Creates the OpenShift project |
| Download plugins | `download_plugins.yml` | `download_plugins`, `build_plugin` | Optional RHSM plugin download |
| Create secrets | `oc_secrets.yml` | `create_secrets`, `create_rhaap_secret`, `create_scm_secret` | Creates `secrets-rhaap-portal` and optional `secrets-scm` |
| Build plugin registry | `plugins.yml` | `build_plugin` | Builds plugins into an OpenShift ImageStream |
| Deploy plugin registry | `plugin_deploy.yml` | `deploy_plugin` | Deploys the plugin registry Deployment and Service |
| Deploy Helm chart | `helm_values.yml` | `helm`, `helm_plugins`, `generate_helm_values` | Installs the chart and waits for the portal Deployment |
| Update OAuth redirect | `update_aap_oauth.yml` | `update_oauth` | Sets the OAuth redirect URI from the portal Route |

---

## Helm Chart

```yaml
chart: https://charts.openshift.io
name: redhat-rhaap-portal
```

**Plugin tarball version must match the Helm chart.** The chart embeds URLs like `http://plugin-registry:8080/ansible-plugin-scaffolder-backend-module-backstage-rhaap-dynamic-X.Y.Z.tgz`. If the extracted RHSM bundle version does not match, the portal init container fails with `npm error 404`.

| AAP / plugin bundle | `helm_chart_version` | Plugin `.tgz` version | RHDH hub image |
|---------------------|----------------------|------------------------|----------------|
| AAP 2.6 (default)   | `2.1.6`              | `2.1.4`                | `1.9`          |
| AAP 2.7             | `2.2.3`              | `2.2.3`                | (chart default) |

Override in your vars file if you use a different bundle. By default the role **auto-detects** the plugin version from extracted `.tgz` files and sets `helm_chart_version` accordingly (`auto_helm_chart_version: true`).

```yaml
# optional — usually not needed:
# helm_chart_version: "2.1.6"
# auto_helm_chart_version: false
```

### External PostgreSQL

By default the chart deploys embedded PostgreSQL in the namespace. For production, set `external_postgresql_enabled: true` and provide connection details in your vars file:

```yaml
external_postgresql_enabled: true
external_postgresql_host: postgres.example.com
external_postgresql_port: 5432
external_postgresql_user: rhdh
external_postgresql_password: secret
external_postgresql_database: rhdh_production
```

The role creates secret `portal-postgresql-external`, disables the embedded Postgres subchart, and passes connection settings to the portal via Helm values ([Red Hat docs](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/extend-proc_self_service_configure_external_database)).

Optional TLS:

```yaml
external_postgresql_ssl_enabled: true
external_postgresql_ssl_reject_unauthorized: true
```

### S3-compatible object storage (TechDocs)

The portal can use S3-compatible storage for **TechDocs** (documentation sites). Enable with:

```yaml
s3_storage_enabled: true
s3_bucket_name: my-techdocs-bucket
s3_region: us-east-1
s3_endpoint: https://s3.amazonaws.com
s3_access_key_id: AKIA...
s3_secret_access_key: secret
s3_force_path_style: true   # keep true for MinIO / ODF ObjectBucketClaim
```

If you already have an OpenShift `ObjectBucketClaim` secret/configmap:

```yaml
s3_storage_enabled: true
s3_use_existing_secret: true
s3_existing_secret_name: obc-secret
s3_existing_configmap_name: obc-configmap
```

TechDocs uses **external** builder mode — documentation is typically generated in CI/CD and uploaded to the bucket separately.

---

## Prerequisites

* Access to a running OpenShift cluster
* **OpenShift internal container registry enabled** — required for the HTTP plugin-registry build (this role uses `pluginMode: tarball` via a local `plugin-registry` ImageStream). If `configs.imageregistry/cluster` has `spec.managementState: Removed`, ask a cluster admin to re-enable the registry before running.
* `oc` and `kubectl` access with permissions to create projects, secrets, builds, and Helm releases
* Local tools: `ansible`, `oc`, `helm` (Helm 3.10+)
* Ansible collections: `redhat.openshift`, `kubernetes.core`, `ansible.platform`
* RHSM offline token (only if `download_plugins: true`)

The role runs preflight checks immediately after variable validation and URL normalization, **before** any AAP or OpenShift changes. Use `--tags preflight` to run those checks alone:

```bash
ansible-playbook deploy-aap-selfservice.yml -e @var_files/aap26-portal.yml --tags preflight
```

| Check | What it catches |
|-------|-----------------|
| Required vars | Missing `aap_host`, `aap_password`, `openshift_namespace`; RHSM token when downloading plugins |
| CLI tools | `oc` and `helm` missing from PATH; Helm too old |
| OpenShift API | Invalid kubeconfig, API unreachable |
| AAP controller | Controller URL unreachable before OAuth/API tasks |
| Plugin directory | Missing extracted plugins when `download_plugins: false` |
| Plugin / chart version | Detects plugin `.tgz` version and auto-selects matching `helm_chart_version` |
| Cluster disk pressure | Warns when nodes report `DiskPressure` (common cause of Helm wait timeouts) |
| Internal registry | Disabled (`Removed`), no storage, RWO + `RollingUpdate` conflict, not `Available` |
| Builder image | Missing `openshift/httpd:2.4-ubi8` ImageStreamTag |
| Stale builds | Non-terminal `plugin-registry` builds blocking the queue (when namespace already exists) |

Preflight also runs automatically when using `--tags build_plugin`, `helm`, or `deploy_plugin`.

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

### If plugin builds fail: internal registry disabled

On your cluster, the integrated registry is currently **Removed**. A cluster admin must re-enable it and configure storage before plugin builds can push to `ImageStreamTag plugin-registry:latest`.

Typical admin steps:

```bash
# Option A: PVC storage (recommended) — claim must be a PVC name string; use Recreate rollout with RWO
oc apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: image-registry-storage
  namespace: openshift-image-registry
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 100Gi
  storageClassName: lvms-vg1
EOF
oc patch configs.imageregistry/cluster --type merge -p \
  '{"spec":{"managementState":"Managed","rolloutStrategy":"Recreate","storage":{"pvc":{"claim":"image-registry-storage"}}}}'

# Option B: emptyDir (lab/testing only — not for production)
# oc patch configs.imageregistry/cluster --type merge -p \
#   '{"spec":{"managementState":"Managed","storage":{"emptyDir":{}}}}'

# Verify the registry becomes Available
oc get configs.imageregistry/cluster -o jsonpath='Available={.status.conditions[?(@.type=="Available")].status}{" "}{.status.conditions[?(@.type=="Available")].message}{"\n"}'
oc get pods -n openshift-image-registry

# Cancel stale plugin builds in your namespace
oc cancel-build -n aap26-self-service -l openshift.io/build-config.name=plugin-registry
```

Then re-run:

```bash
ansible-playbook deploy-aap-selfservice.yml \
  -e @var_files/aap26-portal.yml \
  --tags build_plugin,deploy_plugin
```
