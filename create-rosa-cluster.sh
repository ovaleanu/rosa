#!/bin/bash

echo "Log into cloud.redhat.com and browse to https://cloud.redhat.com/openshift/token/rosa to get the rosa token."

read rosaToken

rosa login --token=${rosaToken}

echo "Verify AWS quota"

rosa verify quota

echo "Create the IAM Account Roles for ROSA"

./rosa create account-roles --mode auto --yes

echo "In what region ROSA cluster will be installed?"

read awsRegion

echo "What is the name of the cluster?"

read rosaClusterName

echo "Create ROSA cluster with STS"

./rosa create cluster --cluster-name ${rosaClusterName} --region ${awsRegion} --sts --mode auto --yes 

./rosa logs install --cluster=${rosaClusterName} --watch

./rosa describe cluster --cluster=${rosaClusterName}

echo "Create an cluster-admin user"

./rosa create admin -c ${rosaClusterName} -p rosaPassword123 > ./.creds

sleep 240  #On MacOs the only unit of time supprted is seconds

grep oc .creds | sh

echo "Adding users to the ROSA cluster"

echo "Specify a htpasswd file to store the user and password information (eg users.htpasswd)"

read fileName

if test -f "./${fileName}"; then
	echo "File named ${fileName} exists already. You need to delete it."
	rm ./${fileName}
else
	echo "We don't have a file named ${fileName}. You will create a new one."
fi

echo "How many users do you need to create?"

read maxUser

echo "What is the default password you will use to set for the users?"

read defaultPassword

i=1

while [ $i -le $maxUser ]
do
	echo "Creating user$i"

	user="user"
	user+=$i

	if [ $i == 1 ]; then
		htpasswd -c -B -b ./${fileName} ${user} ${defaultPassword}
	else 
		htpasswd -B -b ./${fileName} ${user} ${defaultPassword}
	fi

	((i ++))
done

oc get secret htpasswd-secret -ojsonpath={.data.htpasswd} -n openshift-config | base64 --decode > adminuser.htpasswd

awk '{print}' ${fileName} adminuser.htpasswd > allusers.htpasswd

oc create secret generic htpasswd-secret --from-file=htpasswd=./allusers.htpasswd --dry-run=client -o yaml -n openshift-config | oc replace -f -

for (( i=1; i <= $maxUser; i++ ))
do
        echo "Granting cluster-admins role for user$i"

        user="user"
        user+=$i

        ./rosa grant user cluster-admin --user=${user} --cluster=${rosaClusterName}

done
