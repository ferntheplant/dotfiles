export SUBWAY_REDIS_HOST=localhost
export SUBWAY_DB_HOST=localhost

alias startmongo="docker run -d --rm --name mongoContainer -p 27017-27019:27017-27019 -v $HOME/upchieve/mongo-volume:/data/db mongo:4.2.3-bionic"
alias startredis="docker run -d --rm --name redisContainer -p 6379:6379 -v $HOME/upchieve/redis-volume:/data -t redis:5.0.8"
alias killmongo="docker ps -q --filter 'name=mongoContainer' | grep -q . && docker stop mongoContainer"
alias killredis="docker ps -q --filter 'name=redisContainer' | grep -q . && docker stop redisContainer"

alias startargo="kubectl port-forward -n argocd argocd-server-55c946954f-zdjps 8080:8080"

alias startsubway="startmongo && startredis && npx ts-node server/init"
alias killsubway="killmongo && killredis"
alias resetsubway="killsubway && startsubway"

alias killtelepresence="rm -rf /tmp/telepresence-connector.socket && telepresence quit"
alias resettelepresence="killtelepresence && telepresence connect"

alias startdocker="dockerd > /dev/null 2>&1 & disown"
