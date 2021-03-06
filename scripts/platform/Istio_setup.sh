
# ****************************************************************************
# Purpose of the script: 
# 	- Check and Install Kubectl
#	- Create new cluster in Kubernetes
#	- Download and install Istio components
#	- Install Bookinfo application
#	- Setup Ingress Gateway for external access
#	- Verify bookinfo access using GATEWAY_URL
#	- Expose Prometheus and Grafana services using LoadBalancer IP
# ****************************************************************************

echo Check and install Kubectl if it does not exist

KUBECTL_VERSION=$(kubectl version --short | grep Client)

if [ "$KUBECTL_VERSION" == "" ]; then
	echo "kubectl is NOT installed. Installing kubectl"
	sudo apt-get update && sudo apt-get install -y apt-transport-https
	curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
	echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
	sudo apt-get update
	sudo apt-get install -y kubectl
fi

read -p "Enter zone name ["us-central1-c"]: " ZONE_NAME
ZONE_NAME=${ZONE_NAME:-"us-central1-c"}

echo Enter Cluster Name [lowercase letters ONLY]
read CLUSTER_NAME

echo Creating Cluster...
gcloud container clusters create $CLUSTER_NAME \
	 --cluster-version=latest \
	 --machine-type=n1-standard-2 \
	 --zone $ZONE_NAME \
	 --num-nodes 4

echo Creating ClusterRoleBinding ...

kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole=cluster-admin \
  --user=$(gcloud config get-value core/account)

# Initialize environment variables
ISTIO_VERSION=1.1.0
NAME="istio-$ISTIO_VERSION"

echo Check if Istio already downloaded
ISTIOCTL_VERSION=$(istioctl version | grep Version)
if [ "$ISTIOCTL_VERSION" == "" ]; then
	echo Download and install Istio CLI...
	curl -L https://git.io/getLatestIstio | sh -

	echo Adding Istio to PATH
	export PATH=$PWD/$NAME/bin:$PATH
else
	echo "Istio client already installed"
fi

echo Installing Istio components...
kubectl apply -f $PWD/$NAME/install/kubernetes/istio-demo.yaml

echo See if pods are running under istio-system namespace
kubectl get pods -n istio-system

echo Enable sidecar injection
kubectl label namespace default istio-injection=enabled

echo Verify that label was successfully applied
kubectl get namespace -L istio-injection

echo Waiting for a min to complete the installation of Istio components...
sleep 60

echo ***************************************************************
echo Cluster has been created and Istio installed.
echo ***************************************************************


echo Do you want to deploy sample app [Y/n]?
read SAMPLE_APP_DEPLOY

if [ "$SAMPLE_APP_DEPLOY" != "Y" ]
then
	exit 0
fi
	
echo Deploying Bookinfo application...
kubectl apply -f $PWD/$NAME/samples/bookinfo/platform/kube/bookinfo.yaml

echo Waiting for a min to complete the installation of bookinfo app and services...
sleep 60

echo Verify that application has been deployed correctly
kubectl get services
kubectl get pods

echo Define the ingress gateway routing for the application...
kubectl apply -f $PWD/$NAME/samples/bookinfo/networking/bookinfo-gateway.yaml

sleep 60

echo Getting External IP...
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export GATEWAY_URL=$INGRESS_HOST
echo $GATEWAY_URL

echo curl -o /dev/null -s -w \"%{http_code}\\n\" http://${GATEWAY_URL}/api/v1/products
curl -o /dev/null -s -w "%{http_code}\\n" http://${GATEWAY_URL}/api/v1/products

echo Do you want to expose services using LoadBalancer IP [Y/n]?
read EXPOSE_SERVICE_IND

if [ "$EXPOSE_SERVICE_IND" != "Y" ]
then
	exit 0
fi

echo Exposing Prometheus as Load Balancer IP...
kubectl patch svc prometheus -p '{"spec":{"type":"LoadBalancer"}}' -n istio-system

echo Exposing Grafana as Load Balancer IP...
kubectl patch svc grafana -p '{"spec":{"type":"LoadBalancer"}}' -n istio-system

echo Exposing Kiali with Load Balancer IP...
kubectl patch svc kiali -p '{"spec":{"type":"LoadBalancer"}}' -n istio-system

echo Exposing Jaeger Tracing with Load Balancer IP...
kubectl patch svc tracing -p '{"spec":{"type":"LoadBalancer"}}' -n istio-system

# end of script
