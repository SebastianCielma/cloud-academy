from pathlib import Path
import json
import time

import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / ".local-jwt"
OUTPUT.mkdir(exist_ok=True)

ISSUER = "https://issuer.istio-part4.local"
AUDIENCE = "payment-api"
KEY_ID = "part4-local-key"

private_key = rsa.generate_private_key(
    public_exponent=65537,
    key_size=2048,
)

wrong_key = rsa.generate_private_key(
    public_exponent=65537,
    key_size=2048,
)

public_key = private_key.public_key()

pem = private_key.private_bytes(
    serialization.Encoding.PEM,
    serialization.PrivateFormat.PKCS8,
    serialization.NoEncryption(),
)

private_path = OUTPUT / "private.pem"
private_path.write_bytes(pem)
private_path.chmod(0o600)

jwk = json.loads(jwt.algorithms.RSAAlgorithm.to_jwk(public_key))
jwk["kid"] = KEY_ID
jwk["alg"] = "RS256"
jwk["use"] = "sig"

jwks = {"keys": [jwk]}

now = int(time.time())

def create_token(role, expiration, key=private_key):
    claims = {
        "iss": ISSUER,
        "aud": AUDIENCE,
        "sub": "test-user",
        "role": role,
        "iat": now - 10,
        "exp": expiration,
    }
    return jwt.encode(
        claims,
        key,
        algorithm="RS256",
        headers={"kid": KEY_ID},
    )

tokens = {
    "valid": create_token("payment-reader", now + 3600),
    "invalid-signature": create_token(
        "payment-reader", now + 3600, wrong_key
    ),
    "expired": create_token("payment-reader", now - 60),
    "invalid-claims": create_token("viewer", now + 3600),
}

for name, token in tokens.items():
    path = OUTPUT / f"{name}.token"
    path.write_text(token)
    path.chmod(0o600)

manifest = {
    "apiVersion": "security.istio.io/v1",
    "kind": "RequestAuthentication",
    "metadata": {
        "name": "payment-jwt",
        "namespace": "istio-part4",
    },
    "spec": {
        "targetRefs": [
            {
                "group": "",
                "kind": "Service",
                "name": "payment-service",
            }
        ],
        "jwtRules": [
            {
                "issuer": ISSUER,
                "audiences": [AUDIENCE],
                "jwks": json.dumps(jwks),
            }
        ],
    },
}

Path(
    ROOT / "manifests/jwt/01-payment-request-authentication.json"
).write_text(json.dumps(manifest, indent=2) + "\n")

print("JWT test credentials generated locally")
print("RequestAuthentication manifest generated")
print("Private key and tokens stored in .local-jwt/")
