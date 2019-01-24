

# ************************************************************************************************
# Purpose of the script: 
# 	- Create "ratings-v2-mysql" service which connects to external mysql database (in GCloud)
#
# Supported platforms:
#	- Vanilla Kubernetes, Linkerd, Consul
#
# Prerequisite(s):
#	- A cluster and bookinfo application is already setup
#	- Update the DB configuration in samples/bookinfo/platform/kube/bookinfo-ratings-v2-mysql.yaml
#
# Note:
#	- The DB parameters are intentionally left out of the script to avoid exposing secrets.
# *************************************************************************************************

echo Are you sure that the required DB configuration changes done [Y/n]?
read MY_SQL_DB_CONFIG

if [ "$MY_SQL_DB_CONFIG" != "Y" ]; then
	echo Pls. configure the database parameters and retry.
	exit 0
fi

echo Apply the version of the ratings microservice, v2-mysql, that will use database.  
kubectl apply -f istio-1.0.5/samples/bookinfo/platform/kube/bookinfo-ratings-v2-mysql.yaml