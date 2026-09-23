# Example: Deploy a MySQL-backed Python app to App Service within Locally

This example shows how to deploy a small Python notes app ([FastAPI](https://fastapi.tiangolo.com) + [Uvicorn](https://www.uvicorn.org)) to App Service, backed by Azure Database for MySQL Flexible Server, on [Locally Build](https://locally.build).

The application is a minimal notes app: add a note, see the list, delete a note. It's a plain [12-factor](https://12factor.net) service, configured entirely through environment variables, that uses SQLAlchemy and PyMySQL to store notes in MySQL. The source lives in [`app/`](./app) in this repository.

The app authenticates to MySQL using a **user-assigned managed identity**, which is set as the server's Entra administrator. When the app opens a connection it fetches an Entra access token for that identity and sends it as the MySQL password, so no secrets are injected into the app. MySQL Flexible Server still requires an administrator password, so Terraform generates a random one. The app never uses it. Locally supports managed identity the same way Azure does, so the identical wiring works locally and in the cloud.

## Requirements

* [Locally Build](https://locally.build).
* Either [HashiCorp Terraform](https://terraform.io) or [OpenTofu](https://opentofu.org).
* Either [Docker](https://www.docker.com) or [Podman](https://podman.io) (recommended). The build step runs `docker build`/`docker push`, so with Podman make sure `docker` is aliased to (or provided by) Podman.
* The Locally Plugin for `Microsoft.DBforMySQL` installed (`locally plugin install --name Microsoft.DBforMySQL`).
* The Locally Plugin for `Microsoft.Web` installed (`locally plugin install --name Microsoft.Web`).
* The Locally Plugin for `Microsoft.ContainerRegistry` installed (`locally plugin install --name Microsoft.ContainerRegistry`).

## Running the example

First up, we need to ensure our container runtime (Docker or Podman) is running, then launch Locally:

```bash
locally build
```

With Locally running, in another terminal we can initialise Terraform, which both downloads the providers we need and configures the module for use:

```bash
cd environments/locally
terraform init
```

> [!NOTE]
> It's possible to use OpenTofu here by substituting `terraform` for `tofu`.

With Terraform initialised, we can then provision the example by running:

```bash
locally run terraform apply
```

Once you approve the plan and the resources have been deployed, the application is running at the URL in the outputs:

```
https://locally-example-mysql-app.furnace.locally:5663
```

[Open that URL in a browser](https://locally-example-mysql-app.furnace.locally:5663) and you can add and delete notes. Each one is stored as a row in the `notes` table in MySQL.

---

As this Terraform configuration sends the App Service logs into a Log Analytics Workspace, we can then query them within [the Locally Dashboard, in the Monitoring section](https://localhost:5678/monitoring/components), by running:

```
AppServiceConsoleLogs | order by TimeGenerated desc
```

## Notes

This example has no sign-in of its own: anyone who can reach the URL can read and write notes. That keeps it focused on the App Service ↔ MySQL wiring - a real app would sit behind authentication.

The connection to MySQL is always encrypted with TLS. The server certificate is verified only when you point `MYSQL_CA_CERT` at a CA certificate (do this against Azure, using the DigiCert Global Root); Locally's emulator uses a certificate the app image doesn't trust, so verification is skipped by default.

## Tearing it down

```bash
cd environments/locally
locally run terraform destroy
```
