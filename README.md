# Flussonic Watcher helm chart

```
export LICENSE_KEY="PUT-HERE-YOUR-LICENSE-KEY"
export LOGIN="PUT-YOUR-ADMIN-LOGIN"
export PASS="PUT-YOUR-ADMIN-PASS"

kubectl create secret generic flussonic-license \
    --from-literal=license_key="${LICENSE_KEY}" \
    --from-literal=edit_auth="root:password" \
    --from-literal=login="${LOGIN}" \
    --from-literal=pass="${PASS}"
kubectl apply -f https://flussonic.github.io/media-server-operator/latest/operator.yaml
kubectl apply -f https://flussonic.github.io/watcher-operator/latest/operator.yaml
kubectl apply -f https://flussonic.github.io/central-operator/latest/operator.yaml

helm install tw .

```

`tw` here is an example name of your Watcher cluster.


You can always read `mp-start.sh` for launching demo version in your private k3s cluster, launched via [multipass](https://multipass.run/)

