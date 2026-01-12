# Deploying new server

1. Increment the build number in decamp-agent/pubspec.yaml
2. Deploy the server using the command: cd decamp-agent/tool && ./build_release.sh && cd ../..

# Deploying new app
1. Increment the build number in decamp-app/pubspec.yaml
2. Deploy the server using the command: cd decamp-app && ./deploy_ios.sh && cd ..

NOTE: When deploying both apps, build and deploy the server first.
