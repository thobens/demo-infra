# Demo Infra for diverse website deployment

## Deploy Rancher for cluster provisioning

### Local

    docker run -d --restart=unless-stopped \
    -p 80:80 -p 443:443 \
    --privileged \
    rancher/rancher:latest

### Hetzner via terraform

    cd rancher

Make sure to have a `hetzner.auto.tfvars` in the current folder. Set the following variables:

    api_token = "HETZNER_API_TOKEN"
    ssh_keys = "[\"YOUR_SSH_PUBKEY\" ]"

If running for the first time:
    terraform init
    terraform plan

Then run:

    terraform apply


### Configuration

#### Hetzner

##### Install Node Driver

To add hetzner nodes for clusters, open rancher and go to *Tools* - *Driver* in the menu, then open the tab "Node Drivers" and click "Add Node Driver*. Add the following properties:

- Download URL: https://github.com/JonasProgrammer/docker-machine-driver-hetzner/releases/download/3.3.0/docker-machine-driver-hetzner_3.3.0_linux_amd64.tar.gz

- Custom UI URL: https://storage.googleapis.com/hcloud-rancher-v2-ui-driver/component.js

- Whitelist Domains: storage.googleapis.com

## Install stack

    kubectl create namespace flux
    kubectl create configmap flux-ssh-config --from-file=$HOME/.ssh/known_hosts -n flux
    kubectl apply -f bootstrap

## Verify stack

### Grafana Loki

What do you get with Grafana Loki?

All your logs are forwarded to a dashboard
Flexible querying. See a single application log realtime, or search for errors across all your apps
Log based alerts
How to get started after deploy?

Verify the installation with:

    kubectl get pods --namespace infrastructure
    NAME                         READY   STATUS    RESTARTS   AGE
    grafana-5dc6466b8d-2xkwf     1/1     Running   0          47h
    loki-promtail-bvn87          1/1     Running   0          32m
    loki-0                       1/1     Running   0          32m

Forward the internal ClusterIP to your laptop with:

    kubectl port-forward svc/grafana --namespace infrastructure 8888:80

and access the dashboard on http://localhost:8888.

Grafana generates an admin user password, and puts it into a Kubernetes secret. Grab it with:

    kubectl get secret grafana --namespace infrastructure --template='{{ index .data "admin-password"}}' | base64 -d

Make sure to not include the trailing new line character: %

On http://localhost:8888/explore start exploring the application logs by selecting the Loki datasource.

**The tech**

- Grafana 7.0.0 dashboard for querying logs stored in Loki
- Loki 1.5.0 to store the logs
- Promtail 1.5.0 to pick up all your container logs and ship it to Loki

### Nginx

**What do you get with Nginx?**

An Nginx proxy server that routes traffic to your applications based on the host name or path.
How to get started after deploy?

Verify the installation with:

    kubectl get pods,services --namespace infrastructure
    NAME                                                   READY   STATUS    RESTARTS   AGE
    nginx-nginx-ingress-default-backend-6d96c457f6-hfkn8   1/1     Running   0          114s
    nginx-nginx-ingress-controller-6874d7c7f-l7dzc         1/1     Running   0          114s

    NAME                                          TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
    service/nginx-nginx-ingress-controller        LoadBalancer   10.43.199.76    1.2.3.4       80:30377/TCP,443:31126/TCP   114s
    service/nginx-nginx-ingress-default-backend   ClusterIP      10.43.176.181   <none>        80/TCP                       114s

It started the ingress controller pod and the default-backend pod that is served on HTTP 404 requests.

Locate the external IP of the nginx-nginx-ingress-controller service. On local clusters this will always be Pending, but on managed Kubernetes providers, the IP is set within a couple of minutes.

You need to create now DNS entry for this IP. A wildcard DNS on *.yourdomain.com is preferred for this purpose.

To validate the ingress, let's use xip.io, which is a dynamic DNS service: it provides wildcard DNS for any IP address. Say your LAN IP address is 10.0.0.1. Using xip.io, 10.0.0.1.xip.io resolves to 10.0.0.1

Now try https://test.<<yourIP>>.xip.io which will return HTTP 404, served by the just deployed default backend. Indicating that the ingress controller works.

**Next steps:**

add a wildcard DNS entry that points to the nginx-nginx-ingress-controller service's IP
add a Kubernetes ingress object to one of your applications.

### Cert Manager

**What do you get with Cert-Manager?**

Free SSL certificates for all your applications from Let's Encrypt
How to get started after deploy?

Verify the installation with:

    kubectl get pods,clusterissuer --namespace infrastructure

Output:

    NAME                                                   READY   STATUS    RESTARTS   AGE
    cert-manager-cainjector-5c88c48f9-pxc6p                1/1     Running   0          5m2s
    cert-manager-75d94494d6-7zzg4                          1/1     Running   0          5m2s
    cert-manager-webhook-864997b596-jfdpz                  1/1     Running   0          5m2s

NAME                                        READY   AGE
clusterissuer.cert-manager.io/letsencrypt   True    1m
3
Once the ClusterIssuer is created, Cert-Manager is ready to issue Let's Encrypt certificates for your ingresses. It takes about 5 minutes to set it up.

If you enabled Grafana Loki, then you have already a Kubernetes Ingress that utilizes the certificates:

kubectl get ingress -n infrastructure
NAME      HOSTS                       ADDRESS           PORTS     AGE
grafana   grafana.test.laszlo.cloud   172.104.145.220   80, 443   13h
It binds under the grafana subdomain of the host that you set for Nginx, and has the cert-manager.io/cluster-issuer annotation that connects the Ingress with the ClusterIssuer, indicating that Cert-Manager should provision a certificate.

    kubectl get ingress grafana -n infrastructure

Example manifest:

    apiVersion: extensions/v1beta1
    kind: Ingress
    metadata:
    annotations:
        cert-manager.io/cluster-issuer: letsencrypt
        helm.fluxcd.io/antecedent: infrastructure:helmrelease/grafana
        kubernetes.io/ingress.class: nginx
    name: grafana
    namespace: infrastructure
    spec:
    rules:
    - host: grafana.test.laszlo.cloud
        http:
        paths:
        - backend:
            serviceName: grafana
            servicePort: 80
            path: /
    tls:
    - hosts:
        - grafana.test.laszlo.cloud
        secretName: tls-grafana

### Prometheus

**What do you get with Prometheus?**

Infrastructure metrics and dashboards
Integration to application metrics
Default alerts and dashboards
How to get started after deploy?

Verify the installation with:

    kubectl get pods,svc --namespace infrastructure | grep 'prometheus\|grafana'

Output:

    NAME                                                   READY   STATUS    RESTARTS   AGE
    grafana-6987c9c5cf-gsr6x                               1/1     Running   0          66s
    prometheus-kube-state-metrics-c65b87574-qw56j          1/1     Running   0          65s
    prometheus-node-exporter-z8hgt                         1/1     Running   0          65s
    prometheus-pushgateway-7dc7cd5748-zzcc9                1/1     Running   0          65s
    prometheus-alertmanager-78b946d89-8djl8                1/2     Running   0          65s
    prometheus-server-b65c9b875-j62n8                      1/2     Running   0          65s
    service/grafana                               ClusterIP      10.43.64.217    <none>        80/TCP
    service/prometheus-alertmanager               ClusterIP      10.43.154.189   <none>        80/TCP
    service/prometheus-kube-state-metrics         ClusterIP      10.43.66.232    <none>        8080/TCP
    service/prometheus-server                     ClusterIP      10.43.133.254   <none>        80/TCP
    service/prometheus-node-exporter              ClusterIP      None            <none>        9100/TCP
    service/prometheus-pushgateway                ClusterIP      10.43.77.103    <none>        9091/TCP

You can access the dashboards with forwarding the internal Grafana ClusterIP to your laptop with:

    kubectl port-forward svc/grafana --namespace infrastructure 8888:80

and access the dashboard on http://localhost:8888.

Grafana generates an admin user password, and puts it into a Kubernetes secret. Grab it with:

    kubectl get secret grafana --namespace infrastructure --template='{{ inde

### Sealed Secrets

**What do you get with Sealed Secrets?**

A secret manager that allows a simple secret workflow for gitops repositories.
Uses asymmetric cryptography to encrypt secrets, just like HTTPS.
How to get started after deploy?

Verify the installation with:

kubectl get pods --namespace infrastructure
NAME                              READY   STATUS    RESTARTS   AGE
sealed-secrets-7d7cc48f7f-q64sm   1/1     Running   0          14m
Once the pod is running, secrets will be unsealed inside the cluster and made available for your applications.

In order to encrypt secrets, run the following steps:

Install the kubeseal utility

You will use this utility to encrypt secrets for your applications. It uses asymmetric crypto to encrypt secrets that only the controller can decrypt.

Mac:

    brew install kubeseal
Linux:

    wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.15.0/kubeseal-linux-amd64 -O kubeseal
    sudo install -m 755 kubeseal /usr/local/bin/kubeseal

**Steps after first installation**

Perform these steps if you install Sealed Secrets for the first time, and you don't have encrypted secrets in your gitops repo yet.

fetch the sealing key

    kubeseal --fetch-cert --controller-namespace=infrastructure > sealing-key.pub

This key is used to encrypt your secrets. It is only used to encrypt the secrets, noone can decrypt the secrets with this key, so you can share it with anyone.

It is recommended that you add this key as a "Sealing Public Key" to 1-Click Infra bellow, so all keys in the gitops repo will be encrypted.

backup the master key

    kubectl get secret -n infrastructure -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > master.key

Keep this key secret, as this is the only key that can decrypt the secrets. Use it only in case of a cluster restoration.

**Steps after restoration**

Perform these steps if you are restoring your cluster, and you have encrypted secrets in your gitops repo already.

Locate your backed up master key and apply it on the cluster.

    kubectl apply -f master.key

Then restart the Sealed Secrets to pick up the master key:

    kubectl -n infrastructure delete pod -l name=sealed-secrets-controller

Now your cluster can decrypt all secrets from the gitops repo.

### Linkerd

Linkerd is the service mesh on this cluster. See supported features of linerkd: https://linkerd.io/2/features/

Verify installation:

    kubectl get pods --namespace linkerd

Output:

    NAME                                      READY   STATUS    RESTARTS   AGE
    linkerd-controller-59f4765786-jqfxw       2/2     Running   0          25h
    linkerd-destination-6ffd549b85-ssthw      2/2     Running   0          25h
    linkerd-identity-6f8d55bbdb-nqvkx         2/2     Running   0          25h
    linkerd-proxy-injector-685749b6f7-njb5d   2/2     Running   0          25h
    linkerd-sp-validator-5577bb5d85-c4wnn     2/2     Running   0          25h
    linkerd-tap-757fff6d89-pc2rr              2/2     Running   0          25h
    linkerd-web-8446d6bb88-sttk5              2/2     Running   0          25h
Access Linkerd dashboard:

    kubectl port-forward svc/linkerd-web --namespace linkerd 8084:8084
    
Then access localhost:8084 from your browser.
