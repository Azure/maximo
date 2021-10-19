#!/bin/bash

USERNAME="admin"
PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
ENTITLEMENT_KEY="$ENTITLEMENT_KEY"
#CLUSTER_URL="apps.newcluster.maximoonazure.com"

yum install -y git
git clone https://github.com/ibm-watson-iot/iot-docs.git

\cp /tmp/OCPInstall/oc /usr/bin #overwrite existing version

# Set up cert manager

oc create namespace cert-manager
oc apply -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.yaml

# Install catalogs
oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/operatorcatalogs/catalog-source.yaml

# Set up all the operators
oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/servicebinding/service-binding-operator.yaml
# Wait
while [ true ]
do
    installplan=$(oc get installplan -n openshift-operators | grep -i service-binding-operator.v0.8.0 | awk '{print $1}')    
    if [ -z "$installplan" ]
    then
        sleep 2
    else
        break
     fi
done

oc patch installplan ${installplan} -n openshift-operators --type merge --patch '{"spec":{"approved":true}}'

oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/ocs/ocs-operator.yaml

oc create secret docker-registry ibm-entitlement --docker-server=cp.icr.io --docker-username=cp --docker-password=$ENTITLEMENT_KEY -n ibm-sls

oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/sls/sls-operator.yaml
oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/bas/bas-operator.yaml
oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/mas/mas-operator.yaml
oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/strimzi/strimzi-operator.yaml

oc create secret generic database-credentials --from-literal=db_username=${USERNAME} --from-literal=db_password=${PASSWORD} -n ibm-bas
oc create secret generic grafana-credentials --from-literal=grafana_username=${USERNAME} --from-literal=grafana_password=${PASSWORD} -n ibm-bas

oc create secret generic sls-mongo-credentials --from-literal=username=admin --from-literal=password=${PASSWORD} -n ibm-sls

export MONGODB_STORAGE_CLASS="managed-premium"
export MONGO_NAMESPACE=mongo
export MONGO_PASSWORD="${PASSWORD}"

#Install Mongo
cd iot-docs/mongodb/certs/
./generateSelfSignedCert.sh
cd ..
./install-mongo-ce.sh

echo "Waiting for MongoDB to come online"
while [ true ]
do
    status=$(oc get MongoDBCommunity mas-mongo-ce -n mongo -o json | jq -r .status.phase)
    if [ ! "$status" == "Running" ]
    then
        sleep 2
    else
        break
     fi
done


echo "Waiting for operators to come online"

#check SLS
while [ true ]
do
    status=$(oc get ClusterServiceVersion ibm-sls.v3.2.3 -n ibm-sls -o json | jq -r .status.phase)
    if [ ! "$status" == "Succeeded" ]
    then
        sleep 2
    else
        break
     fi
done

echo "SLS Operator Up"

#check BAS Operator
while [ true ]
do
    status=$(oc get ClusterServiceVersion behavior-analytics-services-operator.v1.1.0 -n ibm-bas -o json | jq -r .status.phase)
    if [ ! "$status" == "Succeeded" ]
    then
        sleep 2
    else
        break
     fi
done

echo "MAS Operator Up"

#check MAS
while [ true ]
do
    status=$(oc get ClusterServiceVersion ibm-mas.v8.5.1 -n mas-nonprod-core -o json | jq -r .status.phase)
    if [ ! "$status" == "Succeeded" ]
    then
        sleep 2
    else
        break
     fi
done

echo "Strimzi Operator Up"

#check Kafka
while [ true ]
do
    status=$(oc get ClusterServiceVersion strimzi-cluster-operator.v0.22.1 -n strimzi-kafka -o json | jq -r .status.phase)
    if [ ! "$status" == "Succeeded" ]
    then
        sleep 2
    else
        break
     fi
done

# Deploying


oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/bas/bas-service.yaml
oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/sls/sls-service.yaml
oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/mas/mas-service.yaml
oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/mas/mas-service.yaml
oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/strimzi/strimzi-service.yaml

#check SLS
while [ true ]
do
    status=$(oc get LicenseService sls -n ibm-sls --output='json' | jq -r .status.phase)
    if [ ! "$status" == "Ready" ]
    then
        sleep 2
    else
        break
     fi
done

#check BAS
while [ true ]
do
    status=$(oc get AnalyticsProxy analyticsproxy -n ibm-bas --output='json' | jq -r .status.phase)
    if [ ! "$status" == "Ready" ]
    then
        sleep 2
    else
        break
     fi
done

#check MAS
while [ true ]
do
    status=$(oc get Suite mas-nonprod-core -n mas-nonprod-core --output='json' | jq -r .status.phase)
    if [ ! "$status" == "Ready" ]
    then
        sleep 2
    else
        break
     fi
done

#check Kafka
while [ true ]
do
    status=$(oc get Kafka maskafka -n strimzi-kafka --output='json' | jq -r .status.phase)
    if [ ! "$status" == "Ready" ]
    then
        sleep 2
    else
        break
     fi
done

oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/bas/bas-api-key.yaml

### Info dump:

echo "================ BAS ================"
#openssl s_client -servername bas-endpoint-ibm-bas.${CLUSTER_URL} -connect bas-endpoint-ibm-bas.${CLUSTER_URL}:443 -showcerts