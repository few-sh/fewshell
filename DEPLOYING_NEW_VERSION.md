# Deploying new server

1. Increment the build number in decamp-agent/pubspec.yaml
2. Update the CHANGELOG.md based on server-related git commits since the last version
3. Deploy the server using the command: cd decamp-agent/tool && ./build_release.sh && cd ../..

# Deploying new app
1. Increment the build number in decamp-app/pubspec.yaml
2. Update the CHANGELOG.md based on app-related git commits since the last version
3. Deploy the ios app using the command: cd decamp-app && ./deploy_ios.sh && cd ..
4. Deploy the macos app using the command: cd decamp-app && ./deploy_macos.sh && cd ..

NOTE: When deploying both apps, build and deploy the server first.
