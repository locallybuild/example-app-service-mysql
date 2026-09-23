locals {
  # The application image, built from ../../app and pushed into the Locally
  # Container Registry (see 4-container-registry.tf).
  image_name = "notes-mysql-python"

  # The image is tagged with a hash of the application directory, so any change
  # to the app produces a new tag: that re-triggers the build and push, and rolls
  # the App Service onto the freshly built image. Build artifacts are excluded so
  # they don't churn the hash.
  app_dir = "${path.module}/../../app"
  app_files = [
    for f in fileset(local.app_dir, "**") : f
    if !startswith(f, "node_modules/") && !startswith(f, "dist/") &&
    !startswith(f, "bin/") && !startswith(f, "obj/") &&
    !startswith(f, "__pycache__/") && !startswith(f, ".venv/")
  ]
  image_tag = substr(sha1(join(",", [for f in local.app_files : "${f}:${filesha1("${local.app_dir}/${f}")}"])), 0, 12)

  # The App Service name, used both as the resource name and to compose the
  # public URL.
  web_app_name = "${var.name_prefix}-app"

  # The port the container listens on inside App Service (the app's PORT, exposed
  # to App Service as WEBSITES_PORT). App Service terminates TLS at the platform
  # and routes public traffic to the container on this port.
  app_port = 8080

  # Locally exposes the Flexible Server on a dynamic port encoded in the fqdn
  # ("host:port"), whereas Azure returns a bare hostname served on 3306. Split
  # the fqdn so the app always gets a plain host plus an explicit port that's
  # correct in both places.
  mysql_fqdn = azurerm_mysql_flexible_server.main.fqdn
  mysql_host = split(":", local.mysql_fqdn)[0]
  mysql_port = length(split(":", local.mysql_fqdn)) > 1 ? split(":", local.mysql_fqdn)[1] : "3306"
}
