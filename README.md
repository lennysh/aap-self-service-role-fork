
## 🧾 AAP Self Service Role

This document provides step-by-step instructions to install and configure the Red Hat AAP Self Service Portal using an Ansible role and a Helm chart on OpenShift.

Tested with Ansible Automation Platform 2.6 and Self-Service automation Portal (GA with AAP 2.6)

---

## 📁 Repository Structure

```
aap-ss/
├── deploy-aap-selfservice.yml
├── requirements.yml
├── secrets.yml               # <== You create this file manually
├── role/
│   └── self-service/
│       ├── defaults/
│       ├── files/
│       │   └── plugins/
│       │       ├── self-service-automation-portal-plugins-x.x.x.tar.gz # <== You need to add these manually

│       │       └── ...
│       ├── tasks/
│       │   ├── main.yml
│       │   ├── oauth.yml
│       │   ├── create_token.yml
│       │   ├── namespace.yml
│       │   ├── secrets.yml
│       │   ├── plugins.yml
│       │   └── plugin_deploy.yml
│       └── templates/
```

---

## 🔐 Step 1: Create `secrets.yml` and Update `defaults/main.yml`

This file holds the required variables. It is **not** committed to version control (add it to `.gitignore`).

```yaml
# secrets.yml

controller_username: admin
controller_password: your_aap_admin_password
github_token: github-scm 
gitlab_token: gitlab-scm 

# AAP OAuth/user token will be created automatically

# defaults/main.yml
openshift_namespace: self-service #change if you want a different ns/project
controller_host: "" # AAP Route Endpoint
```

---

## 📦 Step 2: Add Dynamic Plugins

Place your `.tar.gz` plugin packages in:

```
role/self-service/files/plugins/
```

Example:

```
role/self-service/files/plugins/
├── self-service-automation-portal-plugins-x.x.x.tar.gz
├── ansible-rhdh-plugins-x.x.x.tar.gz
└── ...
```

These will be used as the source for the plugin registry build.

---

## 🚀 Step 3: Run the Ansible Role

You can run all steps using:

```bash
ansible-playbook deploy-aap-selfservice.yml

MAC venv: ansible-playbook deploy-aap-selfservice.yml -e "ansible_python_interpreter=$(which python)"

```

---

## 🔧 Step 4: What the Role Does

 Summary: What Happens in This Ansible Role
🔐 Create OAuth2 Application in AAP

File: oauth.yml

Tag: create_oauth

Description: Registers a new OAuth2 application in Ansible Automation Platform (AAP), to support authentication for a plugin or external service.

🔑 Create AAP Token

File: create_token.yml

Tag: create_token

Description: Generates a token (possibly personal or client credential-based) for the OAuth2 app in AAP to allow access to its APIs.

🛠️ Create OpenShift Namespace

File: namespace.yml

Tag: create_namespace

Description: Provisions the target namespace/project in OpenShift where the app will be deployed (e.g., self-service or self-service-dev).

🔐 Create OpenShift Secrets

File: oc_secrets.yml

Tags: create_secrets, create_rhaap_secret, create_scm_secret

Description: Creates Kubernetes secrets in the namespace, including:

secrets-rhaap: holding AAP token/config

secrets-scm: holding GitHub/GitLab tokens for source control integration

📦 Build Plugin Registry

File: plugins.yml

Tag: build_plugin

Description: Builds custom Backstage plugins and pushes them to an OpenShift ImageStream (via BuildConfig).

🚀 Deploy Plugin Registry App

File: plugin_deploy.yml

Tag: deploy_plugin

Description: Deploys the plugin registry to OpenShift using a Deployment + Service + Route.

🧮 Deploy AAP Self Service Helm Chart 

File: helm_values.yml

Tags: helm, helm_plugins, generate_helm_values

Description: Deploys AAP Self Service helm

🔁 Update AAP OAuth2 Application with RHAAP Route

File: update_aap_oauth.yml

Tag: update_oauth

Description: Once RHAAP is deployed, retrieves its Route and updates the AAP OAuth2 app with the correct redirect URI (e.g., /oauth2/callback/).

---

## 📦 Helm Chart

The Helm chart deployed is:

```yaml
chart: https://charts.openshift.io
name: redhat-rhaap-portal
```

---

## ✅ Prerequisites

* You must have access to a running OpenShift cluster
* You must have `oc` and `kubectl` access with cluster-admin permissions
* Your local machine must have:

  * `ansible`
  * `redhat.openshift` and `ansible.platform` collections installed
  * `oc` OpenShift CLI
  * `helm` HELM CLI

```bash
ansible-galaxy collection install redhat.openshift
ansible-galaxy collection install ansible.platform
```

---

## ✅ Optional: requirements.yml

To manage collections in a consistent way, create `requirements.yml`:

```yaml
collections:
  - name: redhat.openshift
  - name: ansible.platform
```

Then run:

```bash
ansible-galaxy install -r requirements.yml
```

