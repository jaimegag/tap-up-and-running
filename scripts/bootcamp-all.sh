# Load Tanzunet Secrets you don't want to show anybody
source ./local-config/tanzunet.sh

# Make sure you point to the right k8s context. Example:
kubectl ctx gke_fe-jaguilar_us-east1_tap

# Install tanzu-cluster-essentials
# Creates namespaces:
#   'tanzu-cluster-essentials',
#   'kapp-controller',
#   'secretgen-controller',
#   'tanzu-package-repo-global'
#
# Installs CRDs, e.g. kapp specific, secretgen specific, package installs, packaging-api, etc.
# Installs kapp-controller, secretgen-controller
mkdir -p ./tanzu-cluster-essentials
tar -xvf tanzu-cluster-essentials-darwin-amd64-1.0.0.tgz -C ./tanzu-cluster-essentials
export INSTALL_BUNDLE=registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@sha256:82dfaf70656b54dcba0d4def85ccae1578ff27054e7533d08320244af7fb0343
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=$TANZU_NET_USERNAME
export INSTALL_REGISTRY_PASSWORD=$TANZU_NET_PASSWORD
pushd ./tanzu-cluster-essentials
./install.sh
popd

#
# Create TAP Installation namespace to hold all the configuration details for the installation.
# 
kubectl create ns tap-install
   
#
# Adds a secret (user/pass) for the Tanzu registry, so we can download necessary binaries.
#
# We also allow the secretgen-controller to export the secret to other namespaces, too.
tanzu secret registry add tap-registry \
  --username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} \
  --server ${INSTALL_REGISTRY_HOSTNAME} \
  --export-to-all-namespaces --yes --namespace tap-install
# to see what this command did  
kubectl get secrets -n tap-install
# to see the secert export configuration so that secretgen-controller can 
# export this secret to other namespaces in the cluster 
kubectl get secretexports.secretgen.carvel.dev -n tap-install

#
# Defines a repository that can be used to pull images from Tanzu net and install them into the cluster.
#
# Image pulling, and deployment of the packages is handled by kapp-controller and carvel tools 
#
export TAP_VERSION=1.0.1
tanzu package repository add tanzu-tap-repository \
  --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} \
  --namespace tap-install
# to see the impact of this command 
tanzu package repository list -n tap-install
# equivalent kubectl command 
kubectl get packagerepositories.packaging.carvel.dev -n tap-install

#
# Inspect the package repositories installed in your Kubernetes cluster.
#
# get more details on the repo 
tanzu package repository get tanzu-tap-repository -n tap-install
# equaivlent kubectl command 
kubectl describe packagerepositories.packaging.carvel.dev -n tap-install
# get available packages
tanzu package available list -n tap-install
# kubectl equivalent 
kubectl get packages -n tap-install

#
# Installs TAP packages
#
tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file ./config/excludeall-tap-values.yaml -n tap-install 
# watch progress with tap and tap-telemetry packages
tanzu package installed list -n tap-install

#
# Inspect Tanzu packages
#
# tanzu cli to get all installed packages 
tanzu package installed get tap -n tap-install
# equivalent kubectl command
kubectl get packageinstalls -n tap-install

#
# Updates Tanzu package to deploy Contour (and cert-manager)
#
tanzu package installed update tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file ./config/contouronly-tap-values.yaml -n tap-install
# watch progress with cert-manager and contour packages
tanzu package installed list -n tap-install
#
# Get Envoy EXTERNAL-IP
kubectl get svc envoy -n tanzu-system-ingress
# Update your DNS configuration
#   Create wildcard A record using the ingress fqdn from your tap-values.yam.
#   Example: *.tap.tap-gke-lab.hyrulelab.com -> Envoy EXTERNAL-IP


#
# Updates Tanzu package to deploy everything else
#
# Inject GCP json and other secrets
cp ./config/tap-values.yaml ./local-config/tap-values.yaml
export GCP_JSON_KEY=$(cat ./local-config/gcp-sa.json)
yq e -i '.buildservice.kp_default_repository_password = strenv(GCP_JSON_KEY)' ./local-config/tap-values.yaml
yq e -i '.buildservice.tanzunet_username = strenv(TANZU_NET_USERNAME)' ./local-config/tap-values.yaml
yq e -i '.buildservice.tanzunet_password = strenv(TANZU_NET_PASSWORD)' ./local-config/tap-values.yaml

#
tanzu package installed update tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file ./local-config/tap-values.yaml -n tap-install
# watch progress with cert-manager and contour packages
tanzu package installed list -n tap-install

#
# Troubleshoot Tanzu package reconciliation errors
#
# Get Package status and USEFUL-ERROR-MESSAGE
tanzu package installed get accelerator -n tap-install 
# Get namespace and check pods
kubectl get all -n accelerator-system
# Check app
kubectl get app accelerator -n tap-install
# TIP: Most likely EVERYTHING will reconcyle eventually without touching it

#
# Create Registry Credentials Secret
# See https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-install-components.html#setup
#
# You need to set the values for your APPS container registry 
#
export APPS_REGISTRY_HOSTNAME="gcr.io"
export APPS_REGISTRY_USERNAME="_json_key"
export APPS_REGISTRY_PASSWORD_FILE="./local-config/gcp-sa.json"
tanzu secret registry add registry-credentials \
  --server ${APPS_REGISTRY_HOSTNAME} \
  --username ${APPS_REGISTRY_USERNAME} --password-file ${APPS_REGISTRY_PASSWORD_FILE} \
  --namespace default
#
# Create namespace RBAC and secret
kubectl apply -n default -f ./config/workload-ns-setup.yaml
# Check secrets. Notice the tap-registry secret was exported to our dev namespace
kubectl get secrets

#
# Import workload backstage catalog info into TAP gui
# 
# 1. Log into TAP GUI using the url defined in your tap-values.yaml file. Example: http://tap-gui.tap.tap-gke-lab.hyrulelab.com
# 2. on the software catalog page click on the register button
# 3. use https://github.com/jaimegag/tanzu-java-web-app/blob/main/catalog-info.yaml for the url in the form
# 4. follow the rest of the instructions in the wizard

#
# Deploy the workload
#
# Use the workload.yaml of this repo. This represents all the ayml devs need to care about
tanzu apps workload create -f ./config/workload.yaml
# Check the status of the workload
tanzu apps workload get tanzu-java-web-app
# Check all logs generated by supply chain components
tanzu apps workload tail tanzu-java-web-app --since 1h

#
# EXpose API Portal
#
# Deploy httpproxy config
kubectl apply -f config/api-portal-httpproxy.yaml
# Access FQDN when httpproxy STATUS is valid. E.g: http://api-portal.tap.tap-gke-lab.hyrulelab.com
kubectl get po,svc,httpproxy -n api-portal

#
# Supply chains insights
#
# Check supply chain from recent workload deployed
kubectl get workloads -A
# Check supply chains configuration
kubectl get ClusterSupplyChain source-to-url -oyaml

# 
# Switch supply chain from basic (source-to-url) to testing_scanning (source-test-scan-to-url)
# https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-getting-started.html#section-4-configure-image-signing-and-verification-in-your-supply-chain-23
#
# Deploy Tekkton Pipline and Scan Policy
kubectl apply -f ./config/tekton-pipeline.yaml
kubectl apply -f ./config/scan-policy.yaml
#
# Update TAP configuration `tap-values.yaml`
# - Set `supply_chain: testing_scanning`
# - Configure the supply-chain configuration block as `ootb_supply_chain_testing_scanning`. Example:
# 
# Update TAP Package
tanzu package installed update tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file ./local-config/tap-values.yaml -n tap-install
# If workload already had the testing tag, the workloadd will be updated with tekton and scanning automatically
# Check the status of the workload
tanzu apps workload get tanzu-java-web-app
# Check all logs generated by supply chain components
tanzu apps workload tail tanzu-java-web-app --since 1h
# Check all workload resources
kubectl get workload,gitrepository,sourcescan,pipelinerun,images.kpack,imagescan,podintent,app,services.serving
#
# Check supply chain from recent workload deployed, the supply chain has changed
kubectl get workloads -A
# Check supply chains configuration
kubectl get ClusterSupplyChain source-test-scan-to-url -oyaml

#
# Deletes entire Tanzu tap package
# 
tanzu apps workload delete tanzu-java-web-app
tanzu package installed delete tap -n tap-install