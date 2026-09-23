"""A minimal notes app backed by Azure Database for MySQL Flexible Server.

Configured entirely through environment variables (12-factor):

    MYSQL_HOST       the server's FQDN
    MYSQL_DATABASE   the database to use
    MYSQL_USER       the MySQL user, which is the managed identity's name
    AZURE_CLIENT_ID  the client id of the user-assigned managed identity
    PORT             the port to listen on

There's no database password. The app signs in to MySQL with an Entra access
token for its managed identity, presented in place of a password.
"""

import html
import logging
import os
import ssl
import time
from contextlib import asynccontextmanager

from azure.identity import DefaultAzureCredential
from fastapi import FastAPI, Form
from fastapi.responses import HTMLResponse, PlainTextResponse, RedirectResponse
from sqlalchemy import create_engine, event, text

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("notes")

MYSQL_HOST = os.environ["MYSQL_HOST"]
# Locally serves MySQL on a non-standard port; Azure uses 3306.
MYSQL_PORT = int(os.environ.get("MYSQL_PORT", "3306"))
MYSQL_DATABASE = os.environ["MYSQL_DATABASE"]
MYSQL_USER = os.environ["MYSQL_USER"]
AZURE_CLIENT_ID = os.environ.get("AZURE_CLIENT_ID")
# Optional path to a CA certificate (PEM) to verify the server against.
MYSQL_CA_CERT = os.environ.get("MYSQL_CA_CERT")

# The scope Azure Database for MySQL (and PostgreSQL) accepts Entra tokens for.
TOKEN_SCOPE = "https://ossrdbms-aad.database.windows.net/.default"

# The web app has a user-assigned identity, so DefaultAzureCredential has to be
# told which one to use - that's what AZURE_CLIENT_ID is for. The same identity
# is the MySQL server's Entra administrator, and is also attached to the server
# itself so the server can validate the tokens it's presented with.
credential = DefaultAzureCredential(managed_identity_client_id=AZURE_CLIENT_ID)

# Locally's MySQL emulator supports TLS, like Azure, and Entra sign-in requires
# it: the token is sent to the server in clear text inside the TLS session, so
# the connection is always encrypted. If a CA certificate is supplied
# (MYSQL_CA_CERT) the server certificate is verified against it - do this against
# Azure, pointing at the DigiCert Global Root. Locally's emulator uses a
# certificate that isn't in this image's trust store, so with no CA supplied
# verification is skipped: encrypted, but the server isn't authenticated.
if MYSQL_CA_CERT:
    tls = ssl.create_default_context(cafile=MYSQL_CA_CERT)
else:
    tls = ssl.create_default_context()
    tls.check_hostname = False
    tls.verify_mode = ssl.CERT_NONE

engine = create_engine(
    f"mysql+pymysql://{MYSQL_USER}@{MYSQL_HOST}:{MYSQL_PORT}/{MYSQL_DATABASE}",
    connect_args={"ssl": tls},
    pool_pre_ping=True,
    # Recycle pooled connections well within a token's lifetime.
    pool_recycle=1800,
)


@event.listens_for(engine, "do_connect")
def use_entra_token_as_password(dialect, conn_rec, cargs, cparams):
    # Entra tokens expire (typically after about an hour), so rather than baking
    # one into the connection URL, fetch one each time the pool opens a new
    # connection. azure-identity caches the token and only refreshes it when
    # it's close to expiry, so this is cheap. An established connection stays
    # valid after its token expires; only new sign-ins need a fresh one.
    cparams["password"] = credential.get_token(TOKEN_SCOPE).token


def create_schema():
    # The database may not accept connections the moment the app starts (for
    # example, while the Entra administrator is still being applied), so retry
    # with backoff before giving up.
    for attempt in range(1, 7):
        try:
            with engine.begin() as conn:
                conn.execute(
                    text(
                        "CREATE TABLE IF NOT EXISTS notes ("
                        " id INT AUTO_INCREMENT PRIMARY KEY,"
                        " body TEXT NOT NULL,"
                        " created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
                        ")"
                    )
                )
            log.info("connected to %s/%s as %s", MYSQL_HOST, MYSQL_DATABASE, MYSQL_USER)
            return
        except Exception as e:
            if attempt == 6:
                raise
            delay = 2**attempt
            log.warning("database not ready (attempt %d): %s - retrying in %ds", attempt, e, delay)
            time.sleep(delay)


@asynccontextmanager
async def lifespan(app: FastAPI):
    create_schema()
    yield


app = FastAPI(lifespan=lifespan)


@app.get("/healthz", response_class=PlainTextResponse)
def healthz():
    return "ok"


PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Notes</title>
<style>
  body {{ font-family: system-ui, sans-serif; max-width: 40rem; margin: 2rem auto; padding: 0 1rem; }}
  form.add {{ display: flex; gap: .5rem; margin-bottom: 1.5rem; }}
  form.add input {{ flex: 1; padding: .4rem; }}
  ul {{ list-style: none; padding: 0; }}
  li {{ display: flex; justify-content: space-between; align-items: center; gap: 1rem; padding: .5rem 0; border-bottom: 1px solid #ddd; }}
  small {{ color: #666; }}
</style>
</head>
<body>
<h1>Notes</h1>
<p><small>Stored in Azure Database for MySQL, signed in with a managed identity.</small></p>
<form class="add" method="post" action="/notes">
  <input name="body" placeholder="Write a note" required autofocus>
  <button type="submit">Add</button>
</form>
<ul>
{items}
</ul>
</body>
</html>
"""

ITEM = """<li><span>{body} <small>{created_at}</small></span>
<form method="post" action="/notes/{id}/delete"><button type="submit">Delete</button></form></li>"""


@app.get("/", response_class=HTMLResponse)
def index():
    with engine.connect() as conn:
        rows = conn.execute(text("SELECT id, body, created_at FROM notes ORDER BY id DESC")).all()
    items = "\n".join(
        ITEM.format(id=r.id, body=html.escape(r.body), created_at=r.created_at) for r in rows
    )
    return PAGE.format(items=items or "<li><small>No notes yet.</small></li>")


@app.post("/notes")
def add_note(body: str = Form(...)):
    with engine.begin() as conn:
        conn.execute(text("INSERT INTO notes (body) VALUES (:body)"), {"body": body})
    return RedirectResponse("/", status_code=303)


@app.post("/notes/{note_id}/delete")
def delete_note(note_id: int):
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM notes WHERE id = :id"), {"id": note_id})
    return RedirectResponse("/", status_code=303)
