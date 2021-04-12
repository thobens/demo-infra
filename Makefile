ns ?= kube-system

.PHONY: 
	help \
	init \
	install \
	fetch-sealing-key \
	update-sealed-secrets \
	hcloud-secret \
	hcloud-csi-secret 

default: help

## help		Display available make targets
help: Makefile
	@sed -n 's/^##//p' $<

## init		Initializes the infrastructure
init:
	@kubectl create namespace flux
	@kubectl create configmap flux-ssh-config --from-file=${HOME}/.ssh/known_hosts -n flux
	@kubectl apply -f bootstrap
	@echo "As soon as the sealed-secret-controller is up, you may generate secrets:"
	@echo "  make update-sealing key"
	@echo "  make hcloud-secret token=<hcloud API token>"
	@echo "  make hcloud-csi-secret token=<hcloud CSI token>"
	@echo "then run `make install`"

## install	Installs the infrastructure. This actually just removes the taint 
##			`node.cloudprovider.kubernetes.io/uninitialized` from all nodes
install:
	@echo "Remove 'uninitialized' taint from all nodes"
	@kubectl taint node --all node.cloudprovider.kubernetes.io/uninitialized=true:NoSchedule-
	@echo "Installing infrastructure..."


## update-sealing-key	Update the sealed secrets on the cluster
update-sealed-secrets:
	@kubectl apply -f hcloud/sealed-hcloud-csi.yaml
	@kubectl apply -f hcloud/sealed-hcloud.yaml
	@kubeseal --fetch-cert --controller-namespace=infrastructure > sealing-key.pub

## fetch-sealing-key	Fetch the sealing key from the sealed-secretes-controller
fetch-sealing-key:
	@kubeseal --fetch-cert --controller-namespace=infrastructure > sealing-key.pub

## hcloud-secret	creates a hcloud secret for the cloud controller manager in the kube-system namespace
hcloud-secret:
	-@echo "${token}" | kubectl -n "$(ns)" create secret generic "hcloud" \
	--dry-run=client --from-file=token=/dev/stdin -o yaml > hcloud/secret-hcloud.yaml
	-@kubeseal --scope=cluster-wide --format yaml --controller-namespace=infrastructure <hcloud/secret-hcloud.yaml >hcloud/sealed-hcloud.yaml
# -@rm hcloud/secret-hcloud.yaml

## hcloud-csi-secret	creates a csi secret for the hcloud csi in the kube-system namespace
hcloud-csi-secret:
	-@echo "${token}" | kubectl -n "$(ns)" create secret generic "hcloud-csi" \
	--dry-run=client --from-file=token=/dev/stdin -o yaml > hcloud/secret-hcloud-csi.yaml
	-@kubeseal --scope=cluster-wide --format yaml --controller-namespace=infrastructure <hcloud/secret-hcloud-csi.yaml >hcloud/sealed-hcloud-csi.yaml
# -@rm hcloud/secret-hcloud-csi.yaml
