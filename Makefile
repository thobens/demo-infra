ns ?= kube-system

.PHONY: 
	help \
	init \
	hcloud-secret \
	hcloud-csi-secret 

default: help

## help		Display available make targets
help: Makefile
	@sed -n 's/^##//p' $<

## init		Initializes the infrastructure
init:
	-@kubeseal --fetch-cert --controller-namespace=infrastructure > sealing-key.pub
	-@kubectl create namespace flux
    -@kubectl create configmap flux-ssh-config --from-file=${HOME}/.ssh/known_hosts -n flux
    -@kubectl apply -f bootstrap

## hcloud-secret	creates a hcloud secret for hetzner in the kube-system namespace
hcloud-secret:
	-@echo "${token}" | kubectl -n "$(ns)" create secret generic "hcloud" \
	--dry-run=client --from-file=token=/dev/stdin -o yaml > hcloud/secret-hcloud.yaml
	-@kubeseal --scope=cluster-wide --format yaml --controller-namespace=infrastructure <hcloud/secret-hcloud.yaml >hcloud/sealed-hcloud.yaml
# -@rm hcloud/secret-hcloud.yaml

## hcloud-csi-secret	creates a csi secret for hetzner in the kube-system namespace
hcloud-csi-secret:
	-@echo "${token}" | kubectl -n "$(ns)" create secret generic "hcloud-csi" \
	--dry-run=client --from-file=token=/dev/stdin -o yaml > hcloud/secret-hcloud-csi.yaml
	-@kubeseal --scope=cluster-wide --format yaml --controller-namespace=infrastructure <hcloud/secret-hcloud-csi.yaml >hcloud/sealed-hcloud-csi.yaml
# -@rm hcloud/secret-hcloud-csi.yaml
