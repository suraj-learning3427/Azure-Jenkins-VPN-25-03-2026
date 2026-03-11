$env:GIT_EDITOR = "echo"
git add .
git commit -m "Step 2: Enable Spoke network deployment"
git push origin branch/corrected_main_tf --force