# Flussonic Watcher helm chart

```
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

