# Power Platform Environment Onboarding Guide

This guide walks you through adding a new Dataverse / Power Platform environment so it can participate in this repository's ALM workflows (export, release, delete). It covers:

1. Azure AD App Registration (service principal)
2. Granting permissions in Power Platform (Application User + roles)
3. Configuring GitHub Environment variables & secrets
4. Verifying connectivity with the Power Platform CLI (optional)
5. (Optional) Adding a new stage beyond DEV / BUILD / QA / PROD

Reference Microsoft tutorial: <https://learn.microsoft.com/power-platform/alm/tutorials/github-actions-start>

---

## 1. Create (or reuse) an Azure AD App Registration

You can use a single app registration across multiple environments as long as it is granted appropriate roles in each. If you already have one supplying `POWERPLATFORMAPPID` / `POWERPLATFORMAPPSECRET` / `TENANTID`, you may reuse it.

Steps (Azure Portal):

1. Azure Active Directory (Entra ID) → App registrations → New registration
2. Name: `powerplatform-alm-sp` (or your convention)
3. Supported account types: Single tenant (recommended)
4. Redirect URI: (leave blank)
5. Register
6. Copy values:
   - Application (client) ID → will become `POWERPLATFORMAPPID`
   - Directory (tenant) ID → will become `TENANTID`
7. Certificates & secrets → New client secret → (optionally 12–24 months) → Copy the secret *value* now → will become `POWERPLATFORMAPPSECRET`.

API permissions: No additional Microsoft Graph permissions are required for Dataverse service-to-service operations via the CLI/actions. Default permissions are sufficient.

Secret rotation: When you rotate the client secret, update the affected GitHub environment secret `POWERPLATFORMAPPSECRET` everywhere it is used.

## 2. Grant the App access inside the Dataverse environment

In each Power Platform environment you want to automate against:

1. Power Platform Admin Center → Environments → (select environment) → Settings
2. Users + permissions → Application users → New app user
3. Add existing app (select the Azure AD app you created) → Next
4. Assign security roles. Minimum required capabilities depend on tasks:
   - For simplicity: System Administrator (broad; good for non‑production or initial setup).
   - Hardened option (create a custom role) requires rights to: Read/Write Customizations, Import Solution, Export Solution, Publish Customizations, Read/Write on solution component entities (e.g., sdkmessageprocessingstep, workflow, webresource).
5. Save/Finish.

Repeat for each environment (DEV, BUILD, QA, PROD, plus any new stage).

## 3. Configure GitHub Environment variables & secrets

Create or update a GitHub Environment (Settings → Environments) corresponding to each Power Platform environment. (This repository currently expects a *single* GitHub environment that houses variables for BUILD + QA + PROD + DEV; adjust if you split these.)

Required variables (per environment):

| Purpose | Variable Name | Example Value |
|---------|---------------|---------------|
| DEV environment URL | `ENVIRONMENTURL_DEV` | `https://org-dev.crm.dynamics.com` |
| BUILD (conversion) environment URL | `ENVIRONMENTURL_BUILD` | `https://org-build.crm.dynamics.com` |
| QA environment URL | `ENVIRONMENTURL_QA` | `https://org-qa.crm.dynamics.com` |
| PROD environment URL | `ENVIRONMENTURL_PROD` | `https://org-prod.crm.dynamics.com` |

Required secrets (repeat in each GitHub Environment — values may be identical if reusing the same app registration):

| Purpose | Secret Name | Source |
|---------|-------------|--------|
| Service principal Application (client) ID | `POWERPLATFORMAPPID` | App registration overview |
| Service principal client secret value | `POWERPLATFORMAPPSECRET` | App registration → Certificates & secrets |
| Azure AD Tenant ID | `TENANTID` | App registration overview |

---

After completing these steps, you can: (a) export a solution from DEV using `export-solution-from-dev.yml`, (b) merge the PR, and (c) trigger a release (manual or via Release creation) to deploy through BUILD → QA → PROD.
