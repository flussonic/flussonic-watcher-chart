#!/bin/bash

set -ex

if [ -f env ]; then
    set -a
    source ./env
    set +a
fi

if [ -z "$LICENSE_KEY" ]; then
    read -p "Enter Flussonic license key: "  LICENSE_KEY
fi

if [ -z "$LOGIN" ]; then
    read -p "Enter Watcher login: "  LOGIN
fi

if [ -z "$PASS" ]; then
    read -p "Enter Watcher password: "  PASS
fi

multipass launch --name watcher --cpus 1 --memory 1024M --disk 5G lts
multipass launch --name streamer1 --cpus 1 --memory 1024M --disk 5G lts
multipass launch --name streamer2 --cpus 1 --memory 1024M --disk 5G lts

# multipass exec watcher -- sudo /bin/sh -c 'curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" INSTALL_K3S_VERSION="v1.25.11+k3s1" sh -'
multipass exec watcher -- sudo /bin/sh -c 'curl -sfL https://get.k3s.io | sh -'

token=$(multipass exec watcher sudo cat /var/lib/rancher/k3s/server/node-token)
plane_ip=$(multipass info watcher | grep -i ip | awk '{print $2}')

multipass exec streamer1 -- sudo /bin/sh -c "curl -sfL https://get.k3s.io | K3S_URL=https://${plane_ip}:6443 K3S_TOKEN=${token} sh -"
multipass exec streamer2 -- sudo /bin/sh -c "curl -sfL https://get.k3s.io | K3S_URL=https://${plane_ip}:6443 K3S_TOKEN=${token} sh -"

multipass exec watcher sudo cat /etc/rancher/k3s/k3s.yaml |sed "s/127.0.0.1/${plane_ip}/" > k3s.yaml
chmod 0400 k3s.yaml
export KUBECONFIG=`pwd`/k3s.yaml

kubectl label nodes watcher flussonic.com/database=true
kubectl label nodes streamer1 flussonic.com/streamer=true
kubectl label nodes streamer2 flussonic.com/streamer=true

kubectl create secret generic flussonic-license --from-literal=license_key="${LICENSE_KEY}"

kubectl create secret generic watcher-admin --from-literal=login="${LOGIN}" --from-literal=pass="${PASS}"

# kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml
# kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
# kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.1/deploy/longhorn.yaml
multipass exec watcher sudo mkdir -p /watcher/postgresql

helm install tw .

watcher_ip=$(multipass info watcher | grep -i ip | awk '{print $2}')
streamer1_ip=$(multipass info streamer1 | grep -i ip | awk '{print $2}')
streamer2_ip=$(multipass info streamer2 | grep -i ip | awk '{print $2}')

echo "Waiting for Postgresql to start" 
kubectl wait --for=condition=Ready pod/tw-flussonic-watcher-web-0

sleep 2
kubectl exec pod/tw-flussonic-watcher-postgres-0  -- \
    /usr/bin/psql -U test -h 127.0.0.1 test_c -c \
    "update domains set settings = jsonb_set(settings, '{dns_names}', '[\"${watcher_ip}\",\"${streamer1_ip}\",\"${streamer2_ip}\"]');"

echo "Watcher ready: http://${watcher_ip}/vsaas  with login/pass: ${LOGIN} ${PASS}"
