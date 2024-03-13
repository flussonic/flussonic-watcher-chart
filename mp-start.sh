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

multipass launch --name watcher --cpus 1 --memory 4096M --disk 20G lts

multipass exec watcher -- sudo apt remove -y snapd multipath-tools

# multipass exec watcher -- sudo /bin/sh -c 'curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" INSTALL_K3S_VERSION="v1.25.11+k3s1" sh -'
multipass exec watcher -- sudo /bin/sh -c 'curl -sfL https://get.k3s.io | sh -'

token=$(multipass exec watcher sudo cat /var/lib/rancher/k3s/server/node-token)
plane_ip=$(multipass info watcher | grep -i ip | awk '{print $2}')


rm -f k3s.yaml
multipass exec watcher sudo cat /etc/rancher/k3s/k3s.yaml |sed "s/127.0.0.1/${plane_ip}/" > k3s.yaml
chmod 0400 k3s.yaml
export KUBECONFIG=`pwd`/k3s.yaml




kubectl label nodes watcher flussonic.com/database=true
multipass exec watcher -- sudo mkdir -p /watcher/postgresql
multipass exec watcher -- sudo mkdir -p /watcher/storage


if [ ! -z "${MULTINODE}" ]; then
    multipass launch --name streamer1 --cpus 1 --memory 1024M --disk 5G lts
    multipass launch --name streamer2 --cpus 1 --memory 1024M --disk 5G lts
    multipass exec streamer1 -- sudo apt remove -y snapd multipath-tools
    multipass exec streamer2 -- sudo apt remove -y snapd multipath-tools

    multipass exec streamer1 -- sudo /bin/sh -c "curl -sfL https://get.k3s.io | K3S_URL=https://${plane_ip}:6443 K3S_TOKEN=${token} sh -"
    multipass exec streamer2 -- sudo /bin/sh -c "curl -sfL https://get.k3s.io | K3S_URL=https://${plane_ip}:6443 K3S_TOKEN=${token} sh -"

    kubectl label nodes streamer1 flussonic.com/streamer=true
    kubectl label nodes streamer2 flussonic.com/streamer=true
    multipass exec streamer1 -- sudo mkdir -p /watcher/storage
    multipass exec streamer2 -- sudo mkdir -p /watcher/storage
else
    kubectl label nodes watcher flussonic.com/streamer=true
fi


kubectl create secret generic flussonic-license \
    --from-literal=license_key="${LICENSE_KEY}" \
    --from-literal=edit_auth="root:password" \
    --from-literal=login="${LOGIN}" \
    --from-literal=pass="${PASS}"

# kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml
# kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
# kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.1/deploy/longhorn.yaml

kubectl apply -f https://flussonic.github.io/media-server-operator/latest/operator.yaml
kubectl apply -f https://flussonic.github.io/watcher-operator/latest/operator.yaml

helm install tw .

watcher_ip=$(multipass info watcher | grep -i ip | awk '{print $2}')

# echo "Waiting for Postgresql to start" 
sleep 2
# kubectl wait --timeout=90s --for=condition=Complete job.batch/tw-watcher-firstrun

# sleep 2
# kubectl exec pod/tw-postgres-0  -- \
#     /usr/bin/psql -U test -h 127.0.0.1 test_c -c \
#     "insert into cloud_streams (name,stream_url,thumbnails,can_ptz,enabled,static,provision_required,domain_id,preset_id,organization_id,folder_id) \
#     values \
#     ('cam1','fake://fake','f','f','t','t','t',1,1,1,1)"


# SESSION=$(curl -sS -f \
#     -H 'content-type:application/json' \
#     -d "{\"login\": \"${LOGIN}\", \"password\": \"${PASS}\"}" \
#     http://${watcher_ip}/vsaas/api/v2/auth/login \
#     | jq -r '.session')

# curl -sS -f -X POST http://${watcher_ip}/vsaas/api/v2/cameras \
#     -H "x-vsaas-session: ${SESSION}" \
#     -H 'content-type: application/json' \
#     -d '{"title": "First Camera", "stream_url": "fake://clock"}'

echo "Watcher ready: http://${watcher_ip}/vsaas  with login/pass: ${LOGIN} ${PASS}"
