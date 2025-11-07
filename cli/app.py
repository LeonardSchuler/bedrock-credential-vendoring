import os
from flask import Flask, redirect, url_for
from authlib.integrations.flask_client import OAuth
from pprint import pprint
from dotenv import load_dotenv

load_dotenv()


app = Flask(__name__)
app.secret_key = os.urandom(24)  # Use a secure random key in production
oauth = OAuth(app)

USER_DIRECTORY_ID = os.environ["USER_DIRECTORY_ID"]
CLIENT_ID = os.environ["CLIENT_ID"]

oauth.register(
    name="oidc",
    authority=f"https://cognito-idp.eu-central-1.amazonaws.com/{USER_DIRECTORY_ID}",
    client_id=CLIENT_ID,
    server_metadata_url=f"https://cognito-idp.eu-central-1.amazonaws.com/{USER_DIRECTORY_ID}/.well-known/openid-configuration",
    client_kwargs={"scope": "email openid profile"},
)


@app.route("/")
def home():
    return f"Successfully authenticated. You can now close this window."


@app.route("/login")
def login():
    # Alternate option to redirect to /authorize
    # return oauth.oidc.authorize_redirect("http://localhost:35002/authorize")
    redirect_uri = url_for("authorize", _external=True)
    return oauth.oidc.authorize_redirect(redirect_uri)


@app.route("/authorize")
def authorize():
    token = oauth.oidc.authorize_access_token()
    user = token["userinfo"]
    pprint(user)
    return redirect(url_for("home"))


if __name__ == "__main__":
    app.run(debug=True)
