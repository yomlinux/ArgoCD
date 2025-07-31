#!/bin/bash
 kubectl create namespace argocd
 kubectl apply -n argocd -f
 kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml
 kubectl get all -n argocd
 kubectl p svc/argocd-server -n argocd 8080:443
 kubectl edit service/argocd-server -n argocd
 kubectl get svc --all-namespaces
 kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

