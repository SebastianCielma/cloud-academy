#!/usr/bin/env bash
set -euo pipefail
umask 077

LOCAL_DIR="$(pwd)/.local/step-ca"
rm -rf "${LOCAL_DIR}"
mkdir -p "${LOCAL_DIR}"

python3 -c 'import secrets; open(".local/step-ca/password.txt", "w").write(secrets.token_urlsafe(24))'

docker run --rm --user 0 -v "${LOCAL_DIR}:/step-out" \
  -e STEPPATH=/step-out/step \
  smallstep/step-cli:0.27.4 \
  step ca init \
    --name="Internal Cloud ACME CA" \
    --dns="step-ca.step-ca.svc.cluster.local,localhost,127.0.0.1" \
    --address=":9000" \
    --provisioner="acme" \
    --deployment-type="standalone" \
    --password-file=/step-out/password.txt \
    --provisioner-password-file=/step-out/password.txt

python3 - << 'INNER'
import json, shutil
b = ".local/step-ca"
cfg = json.load(open(f"{b}/step/config/ca.json"))
cfg["db"] = {"type": "badgerv2", "dataSource": "/home/step/db"}
cfg["root"] = "/home/step/certs/root_ca.crt"
cfg["crt"] = "/home/step/certs/intermediate_ca.crt"
cfg["key"] = "/home/step/secrets/intermediate_ca_key"
cfg["authority"]["provisioners"].append({"type": "ACME", "name": "acme-prov", "claims": {"minTLSCertDuration": "5m", "maxTLSCertDuration": "24h", "defaultTLSCertDuration": "1h"}})
json.dump(cfg, open(f"{b}/ca.json", "w"), indent=2)
for src, dst in [("step/certs/root_ca.crt", "root_ca.crt"), ("step/certs/intermediate_ca.crt", "intermediate_ca.crt"), ("step/secrets/intermediate_ca_key", "intermediate_ca_key"), ("step/config/defaults.json", "defaults.json")]:
    shutil.copyfile(f"{b}/{src}", f"{b}/{dst}")
INNER
echo "step-ca initialized OK."
