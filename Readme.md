# tap-up-and-running
Instructions for the TAP up and Running Bootcamp

scripts to support the demos

Used https://github.com/asaikali/tap-up-and-running as starting point, with different structure and focussed on GKE

## Prepare local config

Create `./local-config/tanzunet.sh` with your TanzuNet credentials
```bash
export TANZU_NET_USERNAME="YOUR_TANZU_NET_USERNAME"
export TANZU_NET_PASSWORD="YOUR_TANZU_NET_PASSWORD"
```

Copy your GCP IAM Service Account json file to `./local-config/gcp-sa.json`

Copy the `tanzu-cluster-essentials-darwin-amd64-1.0.0.tgz ` file to the root of this repo

## Demo

Follow the steps in the `./scripts/bootcamp-all.sh`, and have fun!