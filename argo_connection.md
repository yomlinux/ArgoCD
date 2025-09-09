```
## Add Repo As Needed ##
argocd repo add https://github.com/yomlinux/Pipeline.git --username yomlinux@gmail.com --password <PAT> --name github-pipeline
```
```
## Deploy To Kubernetes ##
argocd app create register-app --repo https://github.com/yomlinux/Pipeline.git --path gitops-register-app --dest-server https://kubernetes.default.svc --dest-namespace default --sync-policy automated
```
