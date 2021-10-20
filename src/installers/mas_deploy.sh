#!/bin/bash

USERNAME="admin"
PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
ENTITLEMENT_KEY="$ENTITLEMENT_KEY"
#CLUSTER_URL="apps.newcluster.maximoonazure.com"

wget https://github.com/mikefarah/yq/releases/download/v4.13.4/yq_linux_amd64.tar.gz -O - | tar xz && mv -f yq_linux_amd64 /usr/bin/yq

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

oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/sls/sls-operator.yaml
oc create secret docker-registry ibm-entitlement --docker-server=cp.icr.io --docker-username=cp --docker-password=$ENTITLEMENT_KEY -n ibm-sls

oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/mas/mas-operator.yaml
oc create secret docker-registry ibm-entitlement --docker-server=cp.icr.io --docker-username=cp --docker-password=$ENTITLEMENT_KEY -n mas-nonprod-core

oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/bas/bas-operator.yaml
oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/strimzi/strimzi-operator.yaml


##### IF exists; Delete and recreate
oc delete secret database-credentials -n ibm-bas
oc delete secret grafana-credentials -n ibm-bas
sleep 1
oc create secret generic database-credentials --from-literal=db_username=${USERNAME} --from-literal=db_password=${PASSWORD} -n ibm-bas
oc create secret generic grafana-credentials --from-literal=grafana_username=${USERNAME} --from-literal=grafana_password=${PASSWORD} -n ibm-bas

export MONGODB_STORAGE_CLASS="managed-premium"
export MONGO_NAMESPACE=mongo
export MONGO_PASSWORD="${PASSWORD}"

#Install Mongo
cd iot-docs/mongodb/certs/
./generateSelfSignedCert.sh
cd ..
./install-mongo-ce.sh

cd ../../

oc delete secret sls-mongo-credentials -n ibm-sls
sleep 1
oc create secret generic sls-mongo-credentials --from-literal=username=admin --from-literal=password=$(oc extract secret/mas-mongo-ce-admin-password --to=- -n mongo) -n ibm-sls

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

oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/bas/bas-api-key.yaml

echo "BAS Service Up"

oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/sls/sls-service.yaml

#check SLS
while [ true ]
do
    status=$(oc get LicenseService sls -n ibm-sls --output='json' | jq -r .status.conditions[0].type)
    if [ ! "$status" == "Ready" ]
    then
        sleep 2
    else
        break
     fi
done

echo "SLS Service Up"

oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/strimzi/strimzi-service.yaml

#check Kafka
while [ true ]
do
    status=$(oc get Kafka maskafka -n strimzi-kafka --output='json' | jq -r .status.conditions[0].type)
    if [ ! "$status" == "Ready" ]
    then
        sleep 2
    else
        break
     fi
done

echo "Kafka Service Up"

#deploy mas
wget https://raw.githubusercontent.com/Azure/maximo/4.6/src/mas/mas-service.yaml -O mas-service.yaml
envsubst < mas-service.yaml > mas-service-nonprod.yaml
oc apply -f mas-service-nonprod.yaml

#slsCfg
oc delete secret nonprod-usersupplied-sls-creds-system -n mas-nonprod-core
sleep 1
oc create secret generic nonprod-usersupplied-sls-creds-system --from-literal=registrationKey=$(oc get LicenseService sls -n ibm-sls --output json | jq -r .status.registrationKey) -n mas-nonprod-core
export slsCert1=$(oc extract secret/sls-cert-api --keys=ca.crt --to=- -n ibm-sls)
#export slsCert2=$(oc extract secret/sls-cert-api --keys=tls.crt --to=- -n ibm-sls)
wget https://raw.githubusercontent.com/Azure/maximo/4.6/src/mas/slsCfg.yaml -O slsCfg.yaml
envsubst < slsCfg.yaml > slsCfg-nonprod.yaml
yq eval ".spec.certificates[0].crt = \"$slsCert1\"" -i slsCfg-nonprod.yaml
#yq eval ".spec.certificates[1].crt = \"$slsCert2\"" -i slsCfg-nonprod.yaml
oc apply -f slsCfg-nonprod.yaml

#basCfg
oc delete secret nonprod-usersupplied-bas-creds-system -n mas-nonprod-core
sleep 1
oc create secret generic nonprod-usersupplied-bas-creds-system --from-literal=api_key=$(oc get secret bas-api-key -n ibm-bas --output="jsonpath={.data.apikey}" | base64 -d) -n mas-nonprod-core
basURL=$(oc get route bas-endpoint -n ibm-bas -o json | jq -r .status.ingress[0].host)
export basCert1=$(openssl s_client -showcerts -servername $basURL -connect $basURL:443 </dev/null 2>/dev/null | openssl x509 -outform PEM)
wget https://raw.githubusercontent.com/Azure/maximo/4.6/src/mas/basCfg.yaml -O basCfg.yaml
envsubst < basCfg.yaml > basCfg-nonprod.yaml
yq eval ".spec.certificates[0].crt = \"$basCert1\"" -i basCfg-nonprod.yaml
oc apply -f basCfg-nonprod.yaml

#mongoCfg
#mas-mongo-ce-cert-secret tls.crt

oc delete secret nonprod-usersupplied-mongo-creds-system -n mas-nonprod-core
sleep 1
oc create secret generic nonprod-usersupplied-mongo-creds-system --from-literal=username=admin --from-literal=password=$(oc extract secret/mas-mongo-ce-admin-password --to=- -n mongo) -n mas-nonprod-core
oc port-forward service/mas-mongo-ce-svc 7000:27017 -n mongo &> /dev/null &
PID=$!
sleep 1
mongoCert1=$(openssl s_client -showcerts -servername localhost -connect localhost:7000 </dev/null 2>/dev/null | openssl x509 -outform PEM)
kill $PID
wget https://raw.githubusercontent.com/Azure/maximo/4.6/src/mas/mongoCfg.yaml -O mongoCfg.yaml
envsubst < mongoCfg.yaml > mongoCfg-nonprod.yaml
yq eval ".spec.certificates[0].crt = \"$mongoCert1\"" -i mongoCfg-nonprod.yaml
oc apply -f mongoCfg-nonprod.yaml

#check MAS
while [ true ]
do
    status=$(oc get Suite nonprod -n mas-nonprod-core --output='json' | jq -r .status.conditions[4].type)
    if [ ! "$status" == "Running" ]
    then
        sleep 2
    else
        break
     fi
done

echo "MAS Service Up"

### Info dump:

echo "================ COMPLETE ================"
#openssl s_client -servername bas-endpoint-ibm-bas.${CLUSTER_URL} -connect bas-endpoint-ibm-bas.${CLUSTER_URL}:443 -showcerts