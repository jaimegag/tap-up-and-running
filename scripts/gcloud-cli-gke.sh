# Create GKE Regional Cluster (No autopilot)
REGION=us-east1
CLUSTER_ZONE="$REGION-c"
CLUSTER_VERSION=$(gcloud container get-server-config --format="yaml(defaultClusterVersion)" --region $REGION | awk '/defaultClusterVersion:/ {print $2}')
gcloud beta container clusters create tap --region $REGION --cluster-version $CLUSTER_VERSION --machine-type "e2-standard-4" --num-nodes "4" --node-locations $CLUSTER_ZONE --enable-pod-security-policy
#gcloud container clusters get-credentials tap --region $REGION
kubectl create clusterrolebinding tap-psp-rolebinding --group=system:authenticated --clusterrole=gce:podsecuritypolicy:privileged


# GCR
# 
# Create Service Acccount with Permissions: "Storage Admin", "Storage Object Creator", "Storage Object Viewer"
# Save keys, to be passed to TBS
#
# Test local access
gcloud auth configure-docker
docker pull busybox
docker tag busybox gcr.io/fe-jaguilar/busybox
docker push gcr.io/fe-jaguilar/busybox
#
# gcr.io/fe-jaguilar/build-service
# gcr.io/fe-jaguilar/supply-chain