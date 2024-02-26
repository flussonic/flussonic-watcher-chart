#!/bin/sh

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

multipass launch --name watcher --cpus 1 --memory 1024M --disk 5G focal
multipass launch --name streamer1 --cpus 1 --memory 1024M --disk 5G focal
multipass launch --name streamer2 --cpus 1 --memory 1024M --disk 5G focal

multipass exec watcher -- sudo /bin/sh -c 'curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" INSTALL_K3S_VERSION="v1.25.11+k3s1" sh -'

token=$(multipass exec watcher sudo cat /var/lib/rancher/k3s/server/node-token)
plane_ip=$(multipass info watcher | grep -i ip | awk '{print $2}')

multipass exec streamer1 -- sudo /bin/sh -c "curl -sfL https://get.k3s.io | K3S_URL=https://${plane_ip}:6443 K3S_TOKEN=${token} sh -"
multipass exec streamer2 -- sudo /bin/sh -c "curl -sfL https://get.k3s.io | K3S_URL=https://${plane_ip}:6443 K3S_TOKEN=${token} sh -"

multipass exec watcher sudo cat /etc/rancher/k3s/k3s.yaml |sed "s/127.0.0.1/${plane_ip}/" > k3s.yaml
export KUBECONFIG=`pwd`/k3s.yaml

kubectl label nodes watcher flussonic.com/streamer=true
kubectl label nodes streamer1 flussonic.com/streamer=true
kubectl label nodes streamer2 flussonic.com/streamer=true

kubectl create secret generic flussonic-license --from-literal=license_key="${LICENSE_KEY}"

kubectl create secret generic watcher-admin --from-literal=login="${LOGIN}" --from-literal=pass="${PASS}"

exit 0

kubectl apply -f 01-postgres.yaml
kubectl apply -f 02-streamer.yaml
kubectl apply -f 03-central.yaml
kubectl apply -f 04-redis.yaml
kubectl apply -f 05-watcher-firstrun.yaml

echo "Waiting for Watcher firstrun (up to 3 minutes)"
kubectl wait --for=condition=complete --timeout=180s job.batch/watcher-firstrun

kubectl apply -f 06-watcher.yaml
kubectl apply -f 07-watcher-services.yaml



watcher_ip=$(multipass info watcher | grep -i ip | awk '{print $2}')

echo "Waiting for Watcher http://${watcher_ip} to start" 
kubectl wait --for=condition=Ready pod/watcher-0

echo "Watcher ready: http://${watcher_ip}/vsaas  with login/pass: ${LOGIN} ${PASS}"
