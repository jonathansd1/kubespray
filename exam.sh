#!/usr/bin/env bash

## This script assumes the following packages/binaries are available:
##   - git
##   - vagrant
##   - virtualbox
##   - gcc zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel tk-devel libffi-devel

ASDF_VERSION=v0.7.4
KUBECTL_VERSION=1.16.2
PYTHON_VERSION=2.7.17
HELM_VERSION=2.15.1

ANSIBLE_INVENTORY=inventory/exam_cluster

## Install asdf-vm
if [ ! -d "${HOME}/.asdf" ] ; then
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch ${ASDF_VERSION}
fi

if ! grep -q "asdf.sh" ${HOME}/.bashrc ; then
  echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc
  echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc
fi

## Ensure we can now run the asdf command
source $HOME/.asdf/asdf.sh

## Install kubectl using asdf
asdf plugin-add kubectl
asdf install kubectl ${KUBECTL_VERSION}
asdf local kubectl ${KUBECTL_VERSION}

## Install python plugin for asdf
asdf plugin-add python
asdf install python ${PYTHON_VERSION}
asdf local python ${PYTHON_VERSION}

## Setup requirements for Kubespray
pip install -r requirements.txt
asdf reshim

cp -a inventory/sample ${ANSIBLE_INVENTORY}
rm -f ${ANSIBLE_INVENTORY}/hosts.ini

mkdir -p vagrant
cat << EOF > vagrant/config.rb
\$inventory = "${ANSIBLE_INVENTORY}"
EOF

## Create K8s cluster
vagrant up

mkdir -p ${HOME}/.kube
ln -sf ${PWD}/${ANSIBLE_INVENTORY}/artifacts/admin.conf ${HOME}/.kube/config

## Install helm, configure K8s cluster for tiller, and initialize
asdf plugin-add helm
asdf install helm ${HELM_VERSION}
asdf local helm ${HELM_VERSION}

kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

helm init --service-account tiller
kubectl -n kube-system rollout status deploy/tiller-deploy
helm version

## Install and configure Jenkins
helm install stable/jenkins --version 1.7.10
