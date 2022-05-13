#!/bin/bash

echo "Log into cloud.redhat.com and browse to https://cloud.redhat.com/openshift/token/rosa to get the rosa token."

read rosaToken

rosa login --token=${rosaToken}

echo "Verify AWS quota"

rosa verify quota

echo "Create the IAM Account Roles for ROSA"

rosa create account-roles --mode auto --yes

echo "In what region ROSA cluster will be installed?"

read awsRegion

echo "What is the name of the cluster?"

read rosaClusterName

echo "Create ROSA cluster with STS"

rosa create cluster --cluster-name ${rosaClusterName} --region ${awsRegion} --sts --mode auto --yes 

rosa logs install --cluster=${rosaClusterName} --watch

rosa describe cluster --cluster=${rosaClusterName}

echo "Create an cluster-admin user"

rosa create admin -c ${rosaClusterName} -p rosaAdminPassword123 > ./.creds

sleep 240  #On MacOs the only unit of time supprted is seconds

grep oc .creds | sh

echo "Add users to the ROSA cluster using HTPassword identity provider"

rosa add --cluster=${rosaClusterName} idp -t htpasswd --interactive

echo "Granting cluster-admins role for users"

echo "Specify the number of users added"

read maxUser

for (( i=1; i <= $maxUser; i++ ))
do
        user="user"
        user+=$i

        rosa grant user cluster-admin --user=${user} --cluster=${rosaClusterName}

done
