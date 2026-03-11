@echo off
set GIT_EDITOR=echo
git merge --abort
git checkout main
git pull origin main
git merge branch/corrected_main_tf --no-edit
git push origin main