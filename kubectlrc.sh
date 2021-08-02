#
# external aliases
# kc cm su
# -- -- --
# |  |  |
# |  |  |---> subcommand (at least 1 char)
# |  |------> command (at least 1 char)
# |---------> kubectl (kc)
alias kca='kubectl apply -f services/hello-blue.yaml'
alias kcc='kubectl create -f services/auth.yaml'
alias kccd='kubectl create deployment hello-server --image=gcr.io/google-samples/hello-app:1.0'
alias kccns='kubectl create ns'
alias kcd='kubectl describe'
alias kcdn='kubectl describe node'
alias kcdp='kubectl describe pod'
alias kcdel='kubectl delete'
alias kced='kubectl edit deployment'
alias kcep='kubectl edit pod'
alias kcex='kubectl exec'
alias kcnd='kubectl explain deployment'
alias kcxd='kubectl expose deployment hello-server --type=LoadBalancer --port 8080'
alias kcgc='kubectl get cronjobs'
alias kcgd='kubectl get deployments'
alias kcge='kubectl get endpoints'
alias kcgj='kubectl get jobs'
alias kcgns='kubectl get namespaces'
alias kcgn='kubectl get nodes'
alias kcgp='kubectl get pods | grep hello- | wc -l'
alias kcgr='kubectl get replicasets'
alias kcgs='kubectl get services'
alias kclo='kubectl logs'
alias kcroh='kubectl rollout history deployment/hello'
alias kcrop='kubectl rollout pause deployment/hello'
alias kcror='kubectl rollout resume deployment/hello'
alias kcros='kubectl rollout status deployment/hello'
alias kcrou='kubectl rollout undo deployment/hello'
alias kcscd='kubectl scale deployment hello --replicas=3'
alias kcsi='kubectl set image deployment/hello'
