NOTE: Run `git fetch` and `git status` before any of the steps below. We should be
on the main branch, it should be up to date and we should have no local modifications.
*STOP AND DO NOT PROCEED* if these conditions are not met.

# Deploying new server

1. Increment the build number in decamp-agent/pubspec.yaml
2. Update the CHANGELOG.md based on server-related git commits since the last version
3. Deploy the server using the command: cd decamp-agent/tool && ./build_release.sh && cd ../..
4. If everything went well, commit the changes using git message format "version: ..." that matches decamp-agent/pubspec.yml version line.

# Deploying new app
1. Increment the build number in decamp-app/pubspec.yaml
2. Update the CHANGELOG.md based on app-related git commits since the last version
3. Deploy the ios app using the command: cd decamp-app && ./deploy_ios.sh && cd ..
4. Deploy the macos app using the command: cd decamp-app && deploy_macos_direct.sh && cd ..
5. Deploy the android app: cd decamp-app && deploy_android.sh && cd ..
6. If everything went well, commit the changes using git message format "version: ..." that matches decamp-app/pubspec.yml version line.

IMPORTANT:
- When deploying both apps, build and deploy the server first.
- agent-core is a shared dependency between client and server, and may contain changes to server, client or both.
- Do not include changes that are not user-facing in the CHANGELOG, eg changes such as updates to documentation or internal scripts are irrelevant.
