#!/bin/bash
bash <(curl -L "https://get.entando.org/cli") --update --release="v7.1.1"
source "$HOME/.entando/activate" --force
ent check-env develop --yes
source "$HOME/.entando/activate" --force
git clone https://github.com/cecchisandrone/entando-simple-bundle.git
cd entando-simple-bunle
ent bundle init simple-bundle
ent bundle pack
