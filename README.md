
## AAP Self Service Role

Install and configure the Red Hat AAP Self Service Portal on OpenShift using an Ansible role and Helm chart.

Tested with Ansible Automation Platform 2.6 and the Self-Service Automation Portal (GA with AAP 2.6).

---

## Repository Structure

```
aap-self-service-role-fork/
├── deploy-aap-selfservice.yml
├── collections/requirements.yml
├── python-requirements.txt
├── var_files/                          # Per-environment vars (gitignored)
│   ├── aap26-portal.yml
│   └── aap27-portal.yml
├── plugins/                            # Plugin bundles by AAP version
│   └── aap26/
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

Create one vars file per target environment under `var_files/`. These files are **not** committed to version control.

Example `var_files/aap26-portal.yml`:

```yaml
---
controller_host: aap.example.com          # AAP route hostname (no https://)
controller_username: admin
controller_password: your_aap_admin_password
openshift_namespace: aap26-self-service
plugin_root_dir: "{{ playbook_dir }}/plugins/aap26/extracted"

# Optional: GitHub/GitLab PATs for SCM integration
# github_token: ghp_your_github_token
# gitlab_token: glpat-your_gitlab_token
```

Required variables:

| Variable | Description |
|----------|-------------|
| `controller_host` | AAP controller route hostname |
| `controller_password` | AAP admin password |
| `openshift_namespace` | OpenShift project for the portal |
| `plugin_root_dir` | Directory containing extracted plugin files |

Optional variables are defined in `self-service/defaults/main.yml` (Helm chart version, OAuth app name, SSL settings, etc.).

The AAP OAuth application and API token are created automatically by the role.

---

## Step 3: Add Dynamic Plugins

Download the **Ansible self-service automation portal Setup Bundle** from the [Red Hat AAP Product Software downloads](https://access.redhat.com/downloads/content/480) page.

Place the bundle under a version-specific directory, for example:

```
plugins/aap26/self-service-automation-portal-plugins-2.1.4.tar.gz
```

Extract the bundle before running the playbook. `plugin_root_dir` must point at the **extracted** files, not the outer `.tar.gz`:

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

Set `plugin_root_dir` in your vars file to that extracted directory.

---

## Step 4: Run the Ansible Role

A vars file **must** be passed on the command line:

```bash
ansible-playbook deploy-aap-selfservice.yml -e @var_files/aap26-portal.yml
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
| Create OAuth2 app | `oauth.yml` | `create_oauth` | Registers an OAuth2 application in AAP |
| Create AAP token | `create_token.yml` | `create_token` | Generates an API token for the OAuth app |
| Create namespace | `namespace.yml` | `create_namespace` | Creates the OpenShift project |
| Create secrets | `oc_secrets.yml` | `create_secrets`, `create_rhaap_secret`, `create_scm_secret` | Creates `secrets-rhaap-portal` and optional `secrets-scm` |
| Build plugin registry | `plugins.yml` | `build_plugin` | Builds plugins into an OpenShift ImageStream |
| Deploy plugin registry | `plugin_deploy.yml` | `deploy_plugin` | Deploys the plugin registry Deployment and Service |
| Deploy Helm chart | `helm_values.yml` | `helm`, `helm_plugins`, `generate_helm_values` | Installs the `redhat-rhaap-portal` chart |
| Update OAuth redirect | `update_aap_oauth.yml` | `update_oauth` | Sets the OAuth redirect URI from the portal Route |

---

## Helm Chart

```yaml
chart: https://charts.openshift.io
name: redhat-rhaap-portal
```

---

## Prerequisites

* Access to a running OpenShift cluster
* `oc` and `kubectl` access with permissions to create projects, secrets, builds, and Helm releases
* Local tools: `ansible`, `oc`, `helm`
* Ansible collections: `redhat.openshift`, `kubernetes.core`, `ansible.platform`

```bash
ansible-galaxy collection install -r collections/requirements.yml
```
